import 'package:equatable/equatable.dart';

import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/entities/budget_thresholds.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../budget/domain/services/budget_calculation_service.dart';
import '../entities/budget_daily_limit_entity.dart';
import '../entities/spending_target_entity.dart';
import '../entities/spending_target_status.dart';

// ---------------------------------------------------------------------------
// Legacy result types (kept for backward compatibility with SpendingTargetBloc)
// ---------------------------------------------------------------------------

sealed class SpendingTargetResult extends Equatable {
  const SpendingTargetResult();
}

class SpendingTargetSuccess extends SpendingTargetResult {
  final SpendingTargetEntity data;
  const SpendingTargetSuccess(this.data);
  @override
  List<Object?> get props => [data];
}

class SpendingTargetError extends SpendingTargetResult {
  final BudgetFailure failure;
  const SpendingTargetError(this.failure);
  @override
  List<Object?> get props => [failure];
}

class SpendingTargetNoBudget extends SpendingTargetResult {
  const SpendingTargetNoBudget();
  @override
  List<Object?> get props => [];
}

// ---------------------------------------------------------------------------
// Per-budget result types
// ---------------------------------------------------------------------------

sealed class PerBudgetSpendingTargetResult extends Equatable {
  const PerBudgetSpendingTargetResult();
}

class PerBudgetSpendingTargetSuccess extends PerBudgetSpendingTargetResult {
  /// Per-budget daily limits — one entry per active budget.
  final List<BudgetDailyLimitEntity> budgetLimits;

  /// Combined daily target (sum of all active budgets' daily limits).
  /// Kept for aggregate views like "Total Remaining".
  final double combinedDailyTarget;

  /// Currency code.
  final String currency;

  const PerBudgetSpendingTargetSuccess({
    required this.budgetLimits,
    required this.combinedDailyTarget,
    required this.currency,
  });

  @override
  List<Object?> get props => [budgetLimits, combinedDailyTarget, currency];
}

class PerBudgetSpendingTargetNoBudget extends PerBudgetSpendingTargetResult {
  const PerBudgetSpendingTargetNoBudget();
  @override
  List<Object?> get props => [];
}

class PerBudgetSpendingTargetError extends PerBudgetSpendingTargetResult {
  final BudgetFailure failure;
  const PerBudgetSpendingTargetError(this.failure);
  @override
  List<Object?> get props => [failure];
}

// ---------------------------------------------------------------------------
// Use case
// ---------------------------------------------------------------------------

/// Calculates daily and weekly spending targets — both per-budget and
/// combined — across all active budgets.
///
/// Reuses [BudgetCalculationService] as the single source of truth for
/// all calculations.
class GetSpendingTargetsUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  const GetSpendingTargetsUseCase({
    required this.repository,
    required this.calculationService,
  });

  // ── Legacy combined target (kept for backward compatibility) ──────────────

  /// Returns combined daily and weekly targets across all active budgets.
  @Deprecated('Use callPerBudget() for per-budget daily limits')
  Future<SpendingTargetResult> call({DateTime? referenceDate}) async {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final allBudgets = await repository.getAllBudgets();
    if (allBudgets.isEmpty) {
      return const SpendingTargetNoBudget();
    }

    final activeBudgets = allBudgets
        .where((b) => !b.isArchived && b.isActiveOn(today))
        .toList();
    if (activeBudgets.isEmpty) {
      return const SpendingTargetNoBudget();
    }

    final weekday = today.weekday;
    final weekStart = today.subtract(Duration(days: weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    var totalDailyTarget = 0.0;
    var totalDailySpent = 0.0;
    var totalWeeklyTarget = 0.0;
    var totalWeeklySpent = 0.0;
    var currency = 'INR';

    for (final budget in activeBudgets) {
      currency = budget.currency;

      final remainingDays = calculationService.calculateRemainingDays(
        referenceDate: today,
        startDate: budget.startDate,
        endDate: budget.endDate,
      );
      final budgetRemaining = calculationService.calculateRemainingBudget(
        monthlyAmount: budget.monthlyAmount,
        totalSpent: budget.monthlyAmount - budget.remainingAmount,
      );

      final dailyAllowance = calculationService.calculateDailyAllowance(
        remainingBudget: budgetRemaining,
        remainingDays: remainingDays,
      );
      totalDailyTarget += dailyAllowance;

      final todaySpent = await repository.getTodaySpending(
        budget.id,
        referenceDate: today,
      );
      totalDailySpent += todaySpent;

      final totalBudgetDays = calculationService.daysInPeriod(
        startDate: budget.startDate,
        endDate: budget.endDate,
      );

      final effectiveWeekStart = weekStart.isBefore(budget.startDate)
          ? budget.startDate
          : weekStart;
      final effectiveWeekEnd = weekEnd.isAfter(budget.endDate)
          ? budget.endDate
          : weekEnd;

      if (effectiveWeekStart.isAfter(effectiveWeekEnd)) {
        continue;
      }

      final daysThisWeek =
          effectiveWeekEnd.difference(effectiveWeekStart).inDays + 1;
      final weeklyTarget =
          budget.monthlyAmount * daysThisWeek / totalBudgetDays;
      totalWeeklyTarget += weeklyTarget;

      final weekSpending = await repository.getExpensesTotalInRange(
        budget.id,
        startDate: weekStart,
        endDate: weekEnd,
      );
      totalWeeklySpent += weekSpending;
    }

    final dailyRemaining = (totalDailyTarget - totalDailySpent).clamp(
      0.0,
      double.infinity,
    );
    final dailyExceeded = totalDailySpent > totalDailyTarget
        ? totalDailySpent - totalDailyTarget
        : 0.0;
    final dailyProgress = totalDailyTarget > 0
        ? (totalDailySpent / totalDailyTarget).clamp(0.0, 1.0)
        : 0.0;
    final dailyStatus = _targetStatus(totalDailySpent, totalDailyTarget);

    final weeklyRemaining = (totalWeeklyTarget - totalWeeklySpent).clamp(
      0.0,
      double.infinity,
    );
    final weeklyExceeded = totalWeeklySpent > totalWeeklyTarget
        ? totalWeeklySpent - totalWeeklyTarget
        : 0.0;
    final weeklyProgress = totalWeeklyTarget > 0
        ? (totalWeeklySpent / totalWeeklyTarget).clamp(0.0, 1.0)
        : 0.0;
    final weeklyStatus = _targetStatus(totalWeeklySpent, totalWeeklyTarget);

    return SpendingTargetSuccess(
      SpendingTargetEntity(
        dailyTarget: totalDailyTarget,
        dailySpent: totalDailySpent,
        dailyRemaining: dailyRemaining,
        dailyExceeded: dailyExceeded,
        dailyProgress: dailyProgress,
        dailyStatus: dailyStatus,
        weeklyTarget: totalWeeklyTarget,
        weeklySpent: totalWeeklySpent,
        weeklyRemaining: weeklyRemaining,
        weeklyExceeded: weeklyExceeded,
        weeklyProgress: weeklyProgress,
        weeklyStatus: weeklyStatus,
        currency: currency,
      ),
    );
  }

  // ── Per-budget targets (primary API) ──────────────────────────────────────

  /// Returns independent daily and weekly limits for each active budget.
  ///
  /// Each budget's limit is calculated using only that budget's:
  /// - Remaining amount
  /// - Remaining days
  /// - Expenses assigned to that budget
  /// - Date range
  Future<PerBudgetSpendingTargetResult> callPerBudget({
    DateTime? referenceDate,
  }) async {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get all non-archived budgets.
    final allBudgets = await repository.getAllBudgets();
    if (allBudgets.isEmpty) {
      return const PerBudgetSpendingTargetNoBudget();
    }

    // Filter to budgets active today.
    final activeBudgets = allBudgets
        .where((b) => !b.isArchived && b.isActiveOn(today))
        .toList();
    if (activeBudgets.isEmpty) {
      return const PerBudgetSpendingTargetNoBudget();
    }

    // Week boundaries (Monday → Sunday).
    final weekday = today.weekday;
    final weekStart = today.subtract(Duration(days: weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final budgetLimits = <BudgetDailyLimitEntity>[];
    var combinedDailyTarget = 0.0;
    var currency = 'INR';

    for (final budget in activeBudgets) {
      currency = budget.currency;

      // ── Daily target for THIS budget ──────────────────────────────────
      final remainingDays = calculationService.calculateRemainingDays(
        referenceDate: today,
        startDate: budget.startDate,
        endDate: budget.endDate,
      );

      final totalSpent = budget.monthlyAmount - budget.remainingAmount;
      final budgetRemaining = calculationService.calculateRemainingBudget(
        monthlyAmount: budget.monthlyAmount,
        totalSpent: totalSpent,
      );

      final dailyLimit = calculationService.calculateDailyAllowance(
        remainingBudget: budgetRemaining,
        remainingDays: remainingDays,
      );

      combinedDailyTarget += dailyLimit;

      // Today's spending for THIS budget only.
      final spentToday = await repository.getTodaySpending(
        budget.id,
        referenceDate: today,
      );

      final remainingToday = (dailyLimit - spentToday).clamp(
        0.0,
        double.infinity,
      );
      final exceededToday = spentToday > dailyLimit
          ? spentToday - dailyLimit
          : 0.0;
      final progress = dailyLimit > 0
          ? (spentToday / dailyLimit).clamp(0.0, 1.0)
          : 0.0;
      final isOverLimit = spentToday > dailyLimit;
      final status = _targetStatus(spentToday, dailyLimit);

      // ── Budget health status ──────────────────────────────────────────
      final utilization = calculationService.calculateBudgetUtilization(
        totalSpent: totalSpent,
        monthlyAmount: budget.monthlyAmount,
      );
      final budgetStatus = calculationService.calculateBudgetStatus(
        budgetUtilization: utilization,
      );

      // ── Weekly target for THIS budget ─────────────────────────────────
      final totalBudgetDays = calculationService.daysInPeriod(
        startDate: budget.startDate,
        endDate: budget.endDate,
      );

      final effectiveWeekStart = weekStart.isBefore(budget.startDate)
          ? budget.startDate
          : weekStart;
      final effectiveWeekEnd = weekEnd.isAfter(budget.endDate)
          ? budget.endDate
          : weekEnd;

      double weeklyTarget = 0;
      double weeklySpent = 0;

      if (!effectiveWeekStart.isAfter(effectiveWeekEnd)) {
        final daysThisWeek =
            effectiveWeekEnd.difference(effectiveWeekStart).inDays + 1;
        weeklyTarget = budget.monthlyAmount * daysThisWeek / totalBudgetDays;

        weeklySpent = await repository.getExpensesTotalInRange(
          budget.id,
          startDate: weekStart,
          endDate: weekEnd,
        );
      }

      final weeklyRemaining = (weeklyTarget - weeklySpent).clamp(
        0.0,
        double.infinity,
      );
      final weeklyExceeded = weeklySpent > weeklyTarget
          ? weeklySpent - weeklyTarget
          : 0.0;
      final weeklyProgress = weeklyTarget > 0
          ? (weeklySpent / weeklyTarget).clamp(0.0, 1.0)
          : 0.0;
      final weeklyStatus = _targetStatus(weeklySpent, weeklyTarget);

      budgetLimits.add(
        BudgetDailyLimitEntity(
          budgetId: budget.id,
          budgetName: budget.name,
          dailyLimit: dailyLimit,
          spentToday: spentToday,
          remainingToday: remainingToday,
          exceededToday: exceededToday,
          progress: progress,
          isOverLimit: isOverLimit,
          status: status,
          budgetStatus: budgetStatus,
          budgetUtilization: utilization,
          monthlyAmount: budget.monthlyAmount,
          totalSpent: totalSpent,
          remainingBudget: budgetRemaining,
          remainingDays: remainingDays,
          weeklyTarget: weeklyTarget,
          weeklySpent: weeklySpent,
          weeklyRemaining: weeklyRemaining,
          weeklyExceeded: weeklyExceeded,
          weeklyProgress: weeklyProgress,
          weeklyStatus: weeklyStatus,
          currency: currency,
          startDate: budget.startDate,
          endDate: budget.endDate,
        ),
      );
    }

    return PerBudgetSpendingTargetSuccess(
      budgetLimits: budgetLimits,
      combinedDailyTarget: combinedDailyTarget,
      currency: currency,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  SpendingTargetStatus _targetStatus(double spent, double target) {
    if (target <= 0) return SpendingTargetStatus.onTrack;
    final ratio = spent / target;
    if (ratio > BudgetThresholds().overBudgetThreshold) {
      return SpendingTargetStatus.exceeded;
    }
    if (ratio >= BudgetThresholds().nearLimitThreshold) {
      return SpendingTargetStatus.nearLimit;
    }
    return SpendingTargetStatus.onTrack;
  }
}
