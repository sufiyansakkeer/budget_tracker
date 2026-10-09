import 'package:intl/intl.dart';

import '../../../../core/theme/app_tone.dart';
import '../../domain/entities/report_data.dart';

/// A comparison sentence and the tone it is read in.
typedef ReportComparison = ({String text, AppTone tone});

/// Wording for the Reports screen, built only from figures the report
/// already carries.
abstract final class ReportCopy {
  static final DateFormat _day = DateFormat('d MMM');

  static const List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// "Mon" … "Sun" for a [DateTime.weekday] (1–7).
  static String shortWeekday(int weekday) =>
      weekdays[weekday - 1].substring(0, 3);

  /// "12% more than the 9 days before (22 – 30 Sep)" from the report's
  /// growth against the equal-length stretch just before it.
  ///
  /// Null when there is nothing to compare: the domain reports no growth at
  /// all when that earlier stretch had no spending, so silence is honest.
  /// More spending reads in the caution tone, less in the positive one.
  static ReportComparison? comparison(ReportData data) {
    final growth = data.trend.growthRate;
    if (growth == 0 || !growth.isFinite) return null;
    final range = data.range;
    final days = range.dayCount;
    final previousEnd = range.start.subtract(const Duration(days: 1));
    final previousStart = range.start.subtract(Duration(days: days));
    final before =
        'the ${days == 1 ? 'day' : '$days days'} before '
        '(${_span(previousStart, previousEnd)})';
    if (growth.abs() < 0.02) {
      return (text: 'About the same as $before', tone: AppTone.neutral);
    }
    final pct = (growth.abs() * 100).round();
    return growth > 0
        ? (text: '$pct% more than $before', tone: AppTone.caution)
        : (text: '$pct% less than $before', tone: AppTone.positive);
  }

  /// "22 – 30 Sep", "28 Sep – 4 Oct", or one day ("30 Sep").
  static String _span(DateTime start, DateTime end) {
    if (start == end) return _day.format(start);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} – ${_day.format(end)}';
    }
    return '${_day.format(start)} – ${_day.format(end)}';
  }
}
