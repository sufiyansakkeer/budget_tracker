import 'package:equatable/equatable.dart';

import '../../../budget/domain/entities/budget_status.dart';
import '../../domain/entities/spending_target_status.dart';

/// Per-budget daily spending limit — the single source of truth for
/// "how much can I spend today on THIS budget".
///
/// Each active budget produces exactly one [BudgetDailyLimitEntity].
/// Combined daily limits are explicitly NOT supported.
class BudgetDailyLimitEntity extends Equatable {
  /// The budget this limit belongs to.
  final String budgetId;

  /// Display name of the budget (e.g. "Food", "Travel").
  final String budgetName;

  /// The daily spending limit for this budget.
  ///
  /// Formula: budget remaining ÷ remaining days for this budget.
  final double dailyLimit;

  /// Amount spent today against THIS budget only.
  final double spentToday;

  /// Remaining amount for today within this budget (never negative).
  final double remainingToday;

  /// Amount exceeding the daily limit today (0 if under limit).
  final double exceededToday;

  /// Progress ratio 0.0–1.0 (capped for visual display).
  final double progress;

  /// Whether this budget is over its daily spending limit.
  final bool isOverLimit;

  /// Status of the daily target for this budget.
  final SpendingTargetStatus status;

  /// The overall budget health status.
  final BudgetStatus budgetStatus;

  /// Percentage of the overall budget used (0–100).
  final double budgetUtilization;

  /// Total budget amount for this budget.
  final double monthlyAmount;

  /// Total spent so far in this budget's period.
  final double totalSpent;

  /// Remaining amount in this budget's overall budget.
  final double remainingBudget;

  /// Number of days remaining in this budget's date range.
  final int remainingDays;

  /// Weekly spending target for this budget.
  final double weeklyTarget;

  /// Amount spent this week against this budget.
  final double weeklySpent;

  /// Remaining amount for this week within this budget.
  final double weeklyRemaining;

  /// Amount exceeding the weekly target (0 if under).
  final double weeklyExceeded;

  /// Weekly progress ratio 0.0–1.0 (capped).
  final double weeklyProgress;

  /// Status of the weekly target for this budget.
  final SpendingTargetStatus weeklyStatus;

  /// Currency code for this budget.
  final String currency;

  /// Start date of this budget's period.
  final DateTime startDate;

  /// End date of this budget's period.
  final DateTime endDate;

  const BudgetDailyLimitEntity({
    required this.budgetId,
    required this.budgetName,
    required this.dailyLimit,
    required this.spentToday,
    required this.remainingToday,
    required this.exceededToday,
    required this.progress,
    required this.isOverLimit,
    required this.status,
    required this.budgetStatus,
    required this.budgetUtilization,
    required this.monthlyAmount,
    required this.totalSpent,
    required this.remainingBudget,
    required this.remainingDays,
    required this.weeklyTarget,
    required this.weeklySpent,
    required this.weeklyRemaining,
    required this.weeklyExceeded,
    required this.weeklyProgress,
    required this.weeklyStatus,
    required this.currency,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [
    budgetId,
    budgetName,
    dailyLimit,
    spentToday,
    remainingToday,
    exceededToday,
    progress,
    isOverLimit,
    status,
    budgetStatus,
    budgetUtilization,
    monthlyAmount,
    totalSpent,
    remainingBudget,
    remainingDays,
    weeklyTarget,
    weeklySpent,
    weeklyRemaining,
    weeklyExceeded,
    weeklyProgress,
    weeklyStatus,
    currency,
    startDate,
    endDate,
  ];
}
