import 'package:equatable/equatable.dart';

import 'budget_status.dart';

/// Extended analytics derived from budget and spending data.
class BudgetAnalyticsEntity extends Equatable {
  final double monthlyAmount;
  final double totalSpent;
  final double remainingBudget;
  final double spendingPercentage;
  final double remainingPercentage;
  final double averageDailySpending;
  final double expectedMonthEndSpending;
  final double projectedRemainingBalance;
  final double projectedSavings;
  final double projectedOverspending;
  final int daysPassed;
  final int daysRemaining;
  final double dailySafeSpending;
  final BudgetStatus status;

  const BudgetAnalyticsEntity({
    required this.monthlyAmount,
    required this.totalSpent,
    required this.remainingBudget,
    required this.spendingPercentage,
    required this.remainingPercentage,
    required this.averageDailySpending,
    required this.expectedMonthEndSpending,
    required this.projectedRemainingBalance,
    required this.projectedSavings,
    required this.projectedOverspending,
    required this.daysPassed,
    required this.daysRemaining,
    required this.dailySafeSpending,
    required this.status,
  });

  @override
  List<Object?> get props => [
    monthlyAmount,
    totalSpent,
    remainingBudget,
    spendingPercentage,
    remainingPercentage,
    averageDailySpending,
    expectedMonthEndSpending,
    projectedRemainingBalance,
    projectedSavings,
    projectedOverspending,
    daysPassed,
    daysRemaining,
    dailySafeSpending,
    status,
  ];
}
