import 'package:equatable/equatable.dart';

import 'spending_target_status.dart';

/// Combined daily and weekly spending targets derived from active budgets.
class SpendingTargetEntity extends Equatable {
  /// Combined daily target across all active budgets.
  final double dailyTarget;

  /// Total spent today across all active budgets.
  final double dailySpent;

  /// Remaining amount for today (never negative).
  final double dailyRemaining;

  /// Amount exceeding the daily target (0 if under target).
  final double dailyExceeded;

  /// Progress ratio 0.0–1.0+ (capped at 1.0 for visual progress).
  final double dailyProgress;

  /// Status of the daily target.
  final SpendingTargetStatus dailyStatus;

  /// Combined weekly target across all active budgets.
  final double weeklyTarget;

  /// Total spent this week across all active budgets.
  final double weeklySpent;

  /// Remaining amount for this week (never negative).
  final double weeklyRemaining;

  /// Amount exceeding the weekly target (0 if under target).
  final double weeklyExceeded;

  /// Progress ratio 0.0–1.0+ (capped at 1.0 for visual progress).
  final double weeklyProgress;

  /// Status of the weekly target.
  final SpendingTargetStatus weeklyStatus;

  /// Currency code shared across all active budgets.
  final String currency;

  const SpendingTargetEntity({
    required this.dailyTarget,
    required this.dailySpent,
    required this.dailyRemaining,
    required this.dailyExceeded,
    required this.dailyProgress,
    required this.dailyStatus,
    required this.weeklyTarget,
    required this.weeklySpent,
    required this.weeklyRemaining,
    required this.weeklyExceeded,
    required this.weeklyProgress,
    required this.weeklyStatus,
    required this.currency,
  });

  /// Whether any active budget exists to compute targets.
  bool get hasActiveBudget => dailyTarget > 0 || weeklyTarget > 0;

  @override
  List<Object?> get props => [
    dailyTarget,
    dailySpent,
    dailyRemaining,
    dailyExceeded,
    dailyProgress,
    dailyStatus,
    weeklyTarget,
    weeklySpent,
    weeklyRemaining,
    weeklyExceeded,
    weeklyProgress,
    weeklyStatus,
    currency,
  ];
}
