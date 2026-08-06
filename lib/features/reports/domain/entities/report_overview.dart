import 'package:equatable/equatable.dart';

/// Summary metrics for the selected report period.
class ReportOverview extends Equatable {
  final double totalSpending;
  final int totalTransactions;
  final double averageDailySpending;
  final double averageTransactionAmount;
  final double highestExpense;
  final double lowestExpense;

  const ReportOverview({
    required this.totalSpending,
    required this.totalTransactions,
    required this.averageDailySpending,
    required this.averageTransactionAmount,
    required this.highestExpense,
    required this.lowestExpense,
  });

  static const empty = ReportOverview(
    totalSpending: 0,
    totalTransactions: 0,
    averageDailySpending: 0,
    averageTransactionAmount: 0,
    highestExpense: 0,
    lowestExpense: 0,
  );

  @override
  List<Object?> get props => [
    totalSpending,
    totalTransactions,
    averageDailySpending,
    averageTransactionAmount,
    highestExpense,
    lowestExpense,
  ];
}
