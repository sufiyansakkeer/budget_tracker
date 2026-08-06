import 'package:equatable/equatable.dart';

/// Supported report periods.
enum ReportPeriod {
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom;

  /// Human-readable label.
  String get label {
    switch (this) {
      case ReportPeriod.thisWeek:
        return 'This Week';
      case ReportPeriod.lastWeek:
        return 'Last Week';
      case ReportPeriod.thisMonth:
        return 'This Month';
      case ReportPeriod.lastMonth:
        return 'Last Month';
      case ReportPeriod.thisYear:
        return 'This Year';
      case ReportPeriod.custom:
        return 'Custom';
    }
  }

  /// Whether this period requires an explicit custom date range.
  bool get isCustom => this == ReportPeriod.custom;
}

/// The resolved date range for a selected [ReportPeriod].
///
/// [start] and [end] are inclusive date boundaries (date part only).
class ReportRange extends Equatable {
  final DateTime start;
  final DateTime end;
  final ReportPeriod period;

  const ReportRange({
    required this.start,
    required this.end,
    required this.period,
  });

  /// Total number of calendar days in the range (inclusive).
  int get dayCount => end.difference(start).inDays + 1;

  /// Whether the range is valid (start not after end).
  bool get isValid => !start.isAfter(end);

  /// Whether the range covers the current calendar month.
  bool get coversCurrentMonth {
    final now = DateTime.now();
    return start.year == now.year &&
        start.month == now.month &&
        end.year == now.year &&
        end.month == now.month;
  }

  @override
  List<Object?> get props => [start, end, period];
}
