import 'package:equatable/equatable.dart';

/// Summary statistics for the currently visible expense results.
class ExpenseHistorySummary extends Equatable {
  final int totalExpenses;
  final double totalAmount;
  final double averageExpense;
  final double highestExpense;
  final double lowestExpense;

  const ExpenseHistorySummary({
    required this.totalExpenses,
    required this.totalAmount,
    required this.averageExpense,
    required this.highestExpense,
    required this.lowestExpense,
  });

  /// Empty summary used when there are no results.
  static const ExpenseHistorySummary empty = ExpenseHistorySummary(
    totalExpenses: 0,
    totalAmount: 0,
    averageExpense: 0,
    highestExpense: 0,
    lowestExpense: 0,
  );

  @override
  List<Object?> get props => [
    totalExpenses,
    totalAmount,
    averageExpense,
    highestExpense,
    lowestExpense,
  ];
}
