import 'package:equatable/equatable.dart';

/// A single daily spending point for the line chart.
class DailySpendingPoint extends Equatable {
  final DateTime date;
  final double amount;

  const DailySpendingPoint({required this.date, required this.amount});

  @override
  List<Object?> get props => [date, amount];
}
