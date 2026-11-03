import 'package:equatable/equatable.dart';

import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/entities/budget_thresholds.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../budget/domain/services/budget_calculation_service.dart';
import '../entities/budget_daily_limit_entity.dart';
import '../entities/spending_target_status.dart';
import 'get_safe_to_spend_usecase.dart';

// ---------------------------------------------------------------------------
// Per-budget result types
// ---------------------------------------------------------------------------

sealed class PerBudgetSpendingTargetResult extends Equatable {
  const PerBudgetSpendingTargetResult();
}

class PerBudgetSpendingTargetSuccess extends PerBudgetSpendingTargetResult {
  /// Per-budget daily limits — one entry per active budget.
  final List<BudgetDailyLimitEntity> budgetLimits;

  const PerBudgetSpendingTargetSuccess({required this.budgetLimits});

  @override
  List<Object?> get props => [budgetLimits];
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

/// Calculates the daily and weekly spending targets of each running budget.
///
/// Today's Safe Spending for each running budget comes from
/// [GetSafeToSpendUseCase] (bills, money kept aside and the savings goal
/// protected); [BudgetCalculationService] remains the single source of the
/// arithmetic.
class GetSpendingTargetsUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  // Private so test doubles that implement this class need not provide it.
  final GetSafeToSpendUseCase _safeToSpend;

  const GetSpendingTargetsUseCase({
    required this.repository,
    required this.calculationService,
    required GetSafeToSpendUseCase safeToSpend,
  }) : _safeToSpend = safeToSpend;

  /// Returns independent daily and weekly limits for each active budget.
  ///
  /// Each budget's limit is calculated using only that budget's:
  /// - Remaining amount
  /// - Remaining days
  /// - Expenses assigned to that budget
  /// - Date range
  ///
  /// Today's Safe Spending comes from [GetSafeToSpendUseCase]: what is free
  /// to spend after upcoming bills, money kept aside and the savings goal,
  /// plus today's own spending, ÷ remaining days (never negative). The
  /// amount is fixed for the day and today's expenses count against it
  /// instead of shrinking it. With nothing set aside it equals
  /// [BudgetCalculationService.calculateTodaySafeSpending] over the SQL
  /// remaining. Each limit carries the full engine result in
  /// [BudgetDailyLimitEntity.safeToSpend].
  ///
  /// The weekly fields are legacy figures that ignore commitments.
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

    // One evaluation for every running budget: one bills read, one
    // committed-spending read, the same day for all.
    final safeToSpend = await _safeToSpend.callForBudgets(
      activeBudgets,
      referenceDate: today,
      allBudgets: allBudgets,
    );

    // Week boundaries (Monday → Sunday), as calendar dates.
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
    );

    final budgetLimits = <BudgetDailyLimitEntity>[];

    for (final budget in activeBudgets) {
      // A budget the engine could not evaluate gets no limit; the others
      // keep theirs.
      final safe = safeToSpend[budget.id];
      if (safe == null) continue;

      // ── Daily target for THIS budget (from the safe-to-spend engine) ──
      final remainingDays = safe.remainingDays;

      // SQL period total, not the stored remaining column.
      final totalSpent = safe.periodSpent;
      final budgetRemaining = safe.availableBalance;

      // Today's spending for THIS budget only, excluding payments of bills
      // it had set aside (already deducted before they were paid).
      final spentToday = safe.todayDiscretionary;

      // Never negative.
      final dailyLimit = safe.dailySafeToSpend;

      final remainingToday = safe.remainingToday;
      final exceededToday = safe.overToday;
      final progress = dailyLimit > 0
          ? (spentToday / dailyLimit).clamp(0.0, 1.0)
          : 0.0;
      final isOverLimit = exceededToday > 0;
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

      // The part of this week inside the budget's period, by calendar date:
      // stored dates can carry a time of day (onboarding used to store the
      // moment it ran), which a raw comparison would count a day short.
      final periodStart = DateTime(
        budget.startDate.year,
        budget.startDate.month,
        budget.startDate.day,
      );
      final periodEnd = DateTime(
        budget.endDate.year,
        budget.endDate.month,
        budget.endDate.day,
      );
      final effectiveWeekStart = weekStart.isBefore(periodStart)
          ? periodStart
          : weekStart;
      final effectiveWeekEnd = weekEnd.isAfter(periodEnd) ? periodEnd : weekEnd;

      double weeklyTarget = 0;
      double weeklySpent = 0;

      if (!effectiveWeekStart.isAfter(effectiveWeekEnd)) {
        final daysThisWeek =
            BudgetCalculationService.calendarDaysBetween(
              effectiveWeekStart,
              effectiveWeekEnd,
            ) +
            1;
        weeklyTarget = budget.monthlyAmount * daysThisWeek / totalBudgetDays;

        // The same days as the target: an expense dated before the budget
        // starts is not this budget's spending (nor its period spending).
        weeklySpent = await repository.getExpensesTotalInRange(
          budget.id,
          startDate: effectiveWeekStart,
          endDate: effectiveWeekEnd,
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
          currency: budget.currency,
          startDate: budget.startDate,
          endDate: budget.endDate,
          safeToSpend: safe,
        ),
      );
    }

    return PerBudgetSpendingTargetSuccess(budgetLimits: budgetLimits);
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
