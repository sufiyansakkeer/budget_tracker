import 'package:equatable/equatable.dart';

import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/entities/budget_thresholds.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../budget/domain/services/budget_calculation_service.dart';
import '../entities/spending_target_entity.dart';
import '../entities/spending_target_status.dart';

/// Raw result type for the spending targets use case.
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

/// Calculates combined daily and weekly spending targets across all active budgets.
///
/// Reuses the existing [BudgetCalculationService] as the single source of truth
/// for all calculations — no duplicate budget math.
class GetSpendingTargetsUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  const GetSpendingTargetsUseCase({
    required this.repository,
    required this.calculationService,
  });

  Future<SpendingTargetResult> call({DateTime? referenceDate}) async {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get all active (non-archived) budgets.
    final allBudgets = await repository.getAllBudgets();
    if (allBudgets.isEmpty) {
      return const SpendingTargetNoBudget();
    }

    // Filter to budgets that are active today.
    final activeBudgets = allBudgets
        .where((b) => !b.isArchived && b.isActiveOn(today))
        .toList();
    if (activeBudgets.isEmpty) {
      return const SpendingTargetNoBudget();
    }

    // Calculate Monday → Sunday week boundaries (date-only).
    final weekday = today.weekday; // 1=Monday, 7=Sunday
    final weekStart = today.subtract(Duration(days: weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    var totalDailyTarget = 0.0;
    var totalDailySpent = 0.0;
    var totalWeeklyTarget = 0.0;
    var totalWeeklySpent = 0.0;
    var currency = 'INR';

    for (final budget in activeBudgets) {
      currency = budget.currency;

      // --- Daily target: use BudgetCalculationService ---
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

      // Today's actual spending from efficient DB query.
      final todaySpent = await repository.getTodaySpending(
        budget.id,
        referenceDate: today,
      );
      totalDailySpent += todaySpent;

      // --- Weekly target: proportional to the budget period ---
      final totalBudgetDays = calculationService.daysInPeriod(
        startDate: budget.startDate,
        endDate: budget.endDate,
      );

      // Compute the actual week coverage within this budget.
      final effectiveWeekStart = weekStart.isBefore(budget.startDate)
          ? budget.startDate
          : weekStart;
      final effectiveWeekEnd = weekEnd.isAfter(budget.endDate)
          ? budget.endDate
          : weekEnd;

      if (effectiveWeekStart.isAfter(effectiveWeekEnd)) {
        // Budget doesn't cover any day this week — skip.
        continue;
      }

      final daysThisWeek =
          effectiveWeekEnd.difference(effectiveWeekStart).inDays + 1;
      final weeklyTarget =
          budget.monthlyAmount * daysThisWeek / totalBudgetDays;
      totalWeeklyTarget += weeklyTarget;

      // This week's spending for this budget.
      final weekSpending = await repository.getExpensesTotalInRange(
        budget.id,
        startDate: weekStart,
        endDate: weekEnd,
      );
      totalWeeklySpent += weekSpending;
    }

    // --- Daily derived values ---
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

    // --- Weekly derived values ---
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

  /// Classifies target health using the same thresholds as the budget engine.
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
