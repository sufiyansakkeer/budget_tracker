import 'package:equatable/equatable.dart';

/// Configurable thresholds used to classify [BudgetStatus].
class BudgetThresholds extends Equatable {
  /// Utilization ratio (0–1) at which status becomes [BudgetStatus.nearLimit].
  final double nearLimitThreshold;

  /// Utilization ratio above which status becomes [BudgetStatus.overBudget].
  final double overBudgetThreshold;

  const BudgetThresholds({
    this.nearLimitThreshold = 0.80,
    this.overBudgetThreshold = 1.0,
  }) : assert(
         nearLimitThreshold > 0 && nearLimitThreshold <= overBudgetThreshold,
       ),
       assert(overBudgetThreshold > 0);

  @override
  List<Object?> get props => [nearLimitThreshold, overBudgetThreshold];
}
