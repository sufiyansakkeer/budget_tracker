import 'package:equatable/equatable.dart';

/// Comparison between a week and the preceding week.
class WeeklyComparison extends Equatable {
  final double currentWeekSpending;
  final double previousWeekSpending;

  /// Difference = current - previous.
  final double difference;

  /// Percentage change (positive = increase, negative = decrease).
  final double percentageChange;

  const WeeklyComparison({
    required this.currentWeekSpending,
    required this.previousWeekSpending,
    required this.difference,
    required this.percentageChange,
  });

  bool get hasPrevious => previousWeekSpending > 0 || currentWeekSpending > 0;

  /// Whether spending went down compared to the previous week.
  bool get isDecrease =>
      percentageChange < 0 || (previousWeekSpending > 0 && difference < 0);

  @override
  List<Object?> get props => [
    currentWeekSpending,
    previousWeekSpending,
    difference,
    percentageChange,
  ];
}
