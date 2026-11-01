import 'package:equatable/equatable.dart';

/// Per-weekday spending total for a range.
class WeekdaySpending extends Equatable {
  final int weekday; // DateTime.monday (1) .. DateTime.sunday (7)
  final double amount;
  final int transactionCount;

  const WeekdaySpending({
    required this.weekday,
    required this.amount,
    required this.transactionCount,
  });

  @override
  List<Object?> get props => [weekday, amount, transactionCount];
}

/// Time-based analytics for the selected report period.
class TimeAnalytics extends Equatable {
  /// Day of the week with the highest total spending (1=Mon .. 7=Sun).
  final int? highestSpendingWeekday;

  /// Total spent on weekdays (Mon-Fri).
  final double weekdaySpending;

  /// Total spent on weekends (Sat-Sun).
  final double weekendSpending;

  /// Breakdown per weekday.
  final List<WeekdaySpending> weekdayBreakdown;

  const TimeAnalytics({
    this.highestSpendingWeekday,
    this.weekdaySpending = 0,
    this.weekendSpending = 0,
    this.weekdayBreakdown = const [],
  });

  static const empty = TimeAnalytics(
    weekdaySpending: 0,
    weekendSpending: 0,
    weekdayBreakdown: [],
  );

  @override
  List<Object?> get props => [
    highestSpendingWeekday,
    weekdaySpending,
    weekendSpending,
    weekdayBreakdown,
  ];
}
