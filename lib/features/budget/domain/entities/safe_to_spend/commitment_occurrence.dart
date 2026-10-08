import 'package:equatable/equatable.dart';

/// One unpaid bill occurrence set aside from a budget.
///
/// Primitives only, so the budget domain never depends on the bills feature;
/// the dashboard's occurrence enumerator builds these from bills.
class CommitmentOccurrence extends Equatable {
  final String billId;
  final String title;

  /// Amount in the budget's currency.
  final double amount;
  final DateTime dueDate;

  /// Due before today (for a running budget: possibly before the period
  /// started). Still owed, and paid from this budget.
  final bool isOverdue;

  const CommitmentOccurrence({
    required this.billId,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.isOverdue = false,
  });

  @override
  List<Object?> get props => [billId, title, amount, dueDate, isOverdue];
}
