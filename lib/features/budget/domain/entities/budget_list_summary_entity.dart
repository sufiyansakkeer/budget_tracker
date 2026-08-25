import 'package:equatable/equatable.dart';

/// Summary of combined metrics across all active budgets.
class BudgetListSummaryEntity extends Equatable {
  /// Total remaining amount across all active budgets (same currency).
  final double totalRemaining;

  /// Number of active budgets included in the summary.
  final int activeBudgetCount;

  /// Currency code (all budgets must use same currency).
  final String currency;

  const BudgetListSummaryEntity({
    required this.totalRemaining,
    required this.activeBudgetCount,
    required this.currency,
  });

  @override
  List<Object?> get props => [totalRemaining, activeBudgetCount, currency];
}
