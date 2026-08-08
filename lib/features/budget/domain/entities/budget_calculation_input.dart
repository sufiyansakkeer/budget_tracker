import 'package:equatable/equatable.dart';

import 'budget_thresholds.dart';

/// Raw data consumed by [BudgetCalculationService] for pure calculations.
///
/// Contains no database or UI dependencies.
class BudgetCalculationInput extends Equatable {
  final double monthlyAmount;
  final double totalSpent;
  final double todaySpending;
  final DateTime referenceDate;
  final DateTime startDate;
  final DateTime endDate;
  final BudgetThresholds thresholds;

  const BudgetCalculationInput({
    required this.monthlyAmount,
    required this.totalSpent,
    required this.todaySpending,
    required this.referenceDate,
    required this.startDate,
    required this.endDate,
    this.thresholds = const BudgetThresholds(),
  });

  @override
  List<Object?> get props => [
    monthlyAmount,
    totalSpent,
    todaySpending,
    referenceDate,
    startDate,
    endDate,
    thresholds,
  ];
}
