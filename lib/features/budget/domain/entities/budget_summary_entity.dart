import 'package:equatable/equatable.dart';

import 'budget_status.dart';

/// Snapshot of key budget metrics for dashboard and summary views.
class BudgetSummaryEntity extends Equatable {
  final double monthlyAmount;
  final double remainingBudget;
  final double totalSpent;
  final double todaySpending;
  final int remainingDays;
  final int daysPassed;
  final double dailySafeSpending;
  final double budgetUtilization;
  final double spendingPercentage;
  final double remainingPercentage;
  final double averageDailySpending;
  final double expectedMonthEndSpending;
  final double expectedSavings;
  final double expectedOverspending;
  final double todayOverspending;
  final BudgetStatus status;
  final String currency;
  final int budgetMonth;
  final int budgetYear;

  const BudgetSummaryEntity({
    required this.monthlyAmount,
    required this.remainingBudget,
    required this.totalSpent,
    required this.todaySpending,
    required this.remainingDays,
    required this.daysPassed,
    required this.dailySafeSpending,
    required this.budgetUtilization,
    required this.spendingPercentage,
    required this.remainingPercentage,
    required this.averageDailySpending,
    required this.expectedMonthEndSpending,
    required this.expectedSavings,
    required this.expectedOverspending,
    required this.todayOverspending,
    required this.status,
    required this.currency,
    required this.budgetMonth,
    required this.budgetYear,
  });

  @override
  List<Object?> get props => [
        monthlyAmount,
        remainingBudget,
        totalSpent,
        todaySpending,
        remainingDays,
        daysPassed,
        dailySafeSpending,
        budgetUtilization,
        spendingPercentage,
        remainingPercentage,
        averageDailySpending,
        expectedMonthEndSpending,
        expectedSavings,
        expectedOverspending,
        todayOverspending,
        status,
        currency,
        budgetMonth,
        budgetYear,
      ];
}
