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
  /// Day with the highest total spending (non-null when expenses exist).
  final DateTime? mostExpensiveDay;

  /// Day with the lowest total spending among active spending days.
  final DateTime? cheapestDay;

  /// Calendar day with the most transactions.
  final DateTime? mostActiveDay;

  /// Calendar day with the fewest transactions among active days.
  final DateTime? leastActiveDay;

  /// Day of the week with the highest total spending (1=Mon .. 7=Sun).
  final int? highestSpendingWeekday;

  /// Total spent on weekdays (Mon-Fri).
  final double weekdaySpending;

  /// Total spent on weekends (Sat-Sun).
  final double weekendSpending;

  /// Breakdown per weekday.
  final List<WeekdaySpending> weekdayBreakdown;

  const TimeAnalytics({
    this.mostExpensiveDay,
    this.cheapestDay,
    this.mostActiveDay,
    this.leastActiveDay,
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
    mostExpensiveDay,
    cheapestDay,
    mostActiveDay,
    leastActiveDay,
    highestSpendingWeekday,
    weekdaySpending,
    weekendSpending,
    weekdayBreakdown,
  ];
}
