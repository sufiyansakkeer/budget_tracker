import 'package:equatable/equatable.dart';

/// Aggregated expense statistics for a budget month.
class MonthlyStatisticsEntity extends Equatable {
  final double totalSpent;
  final int expenseCount;
  final double todaySpending;

  const MonthlyStatisticsEntity({
    required this.totalSpent,
    required this.expenseCount,
    required this.todaySpending,
  });

  static const empty = MonthlyStatisticsEntity(
    totalSpent: 0,
    expenseCount: 0,
    todaySpending: 0,
  );

  @override
  List<Object?> get props => [totalSpent, expenseCount, todaySpending];
}
