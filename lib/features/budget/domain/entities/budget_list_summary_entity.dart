import 'package:equatable/equatable.dart';

/// Summary of combined metrics across all active budgets.
class BudgetListSummaryEntity extends Equatable {
  /// Remaining amount of the active budgets added up per currency, in the
  /// order the currencies first appear. Amounts in different currencies are
  /// never added together or converted: OMR 100 and ₹10,000 are two totals,
  /// not "OMR 10,100".
  final Map<String, double> remainingByCurrency;

  /// Number of active budgets included in the summary.
  final int activeBudgetCount;

  const BudgetListSummaryEntity({
    required this.remainingByCurrency,
    required this.activeBudgetCount,
  });

  static const empty = BudgetListSummaryEntity(
    remainingByCurrency: {},
    activeBudgetCount: 0,
  );

  @override
  List<Object?> get props => [remainingByCurrency, activeBudgetCount];
}
