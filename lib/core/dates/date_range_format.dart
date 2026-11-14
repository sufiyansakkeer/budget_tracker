import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Every date and time the app shows, in one order: day, month, year
/// ("5 Nov 2026"), never the US "Nov 5, 2026".
///
/// Short forms drop the year only when the date is in the current year
/// ([now] defaults to the clock), so a date from another year is never
/// ambiguous. Times follow the device's 12/24-hour setting through
/// [TimeOfDay.format].
///
/// Machine formats (`yyyy-MM-dd` payloads, file names, CSV) are not here:
/// they are data, not display.
abstract final class AppDates {
  static final DateFormat _d = DateFormat('d MMM');
  static final DateFormat _dy = DateFormat('d MMM yyyy');
  static final DateFormat _wd = DateFormat('EEE d MMM');
  static final DateFormat _wdy = DateFormat('EEE d MMM yyyy');
  static final DateFormat _long = DateFormat('d MMMM yyyy');
  static final DateFormat _spoken = DateFormat('d MMMM');
  static final DateFormat _longWeekday = DateFormat('EEEE d MMMM');
  static final DateFormat _weekdayName = DateFormat('EEEE');
  static final DateFormat _weekdayShort = DateFormat('E');
  static final DateFormat _month = DateFormat('MMM');
  static final DateFormat _monthYear = DateFormat('MMM yyyy');
  static final DateFormat _monthShortYear = DateFormat("MMM ''yy");

  static bool _thisYear(DateTime d, DateTime? now) =>
      d.year == (now ?? DateTime.now()).year;

  /// "5 Nov", or "5 Nov 2025" outside the current year.
  static String day(DateTime d, {DateTime? now}) =>
      (_thisYear(d, now) ? _d : _dy).format(d);

  /// "5 Nov", never with the year: only for labels inside a period that
  /// already states its year (chart axes and bars).
  static String dayMonth(DateTime d) => _d.format(d);

  /// "Thu 5 Nov", never with the year; see [dayMonth].
  static String weekdayMonth(DateTime d) => _wd.format(d);

  /// "5 Nov 2026", always with the year.
  static String dayWithYear(DateTime d) => _dy.format(d);

  /// "Thu 5 Nov", or "Thu 5 Nov 2025" outside the current year.
  static String weekday(DateTime d, {DateTime? now}) =>
      (_thisYear(d, now) ? _wd : _wdy).format(d);

  /// "Thu 5 Nov 2026", always with the year (details and form fields).
  static String fullDay(DateTime d) => _wdy.format(d);

  /// "5 November 2026".
  static String longDay(DateTime d) => _long.format(d);

  /// "5 November", or "5 November 2025" outside the current year: the
  /// spoken form of [day] for screen readers.
  static String spokenDay(DateTime d, {DateTime? now}) =>
      (_thisYear(d, now) ? _spoken : _long).format(d);

  /// "Thursday 5 November", for today in a greeting.
  static String longWeekday(DateTime d) => _longWeekday.format(d);

  /// "Thursday".
  static String weekdayName(DateTime d) => _weekdayName.format(d);

  /// "Thu", for chart axes.
  static String weekdayShort(DateTime d) => _weekdayShort.format(d);

  /// "Nov", or with [withYear] "Nov 2026".
  static String month(DateTime d, {bool withYear = false}) =>
      (withYear ? _monthYear : _month).format(d);

  /// "Nov '26", for chart axes that span years.
  static String monthShortYear(DateTime d) => _monthShortYear.format(d);

  /// The time of day in the device's 12- or 24-hour format ("9:00 AM" or
  /// "09:00").
  static String time(BuildContext context, DateTime t) =>
      TimeOfDay.fromDateTime(t).format(context);

  /// "5 Nov 2026, 9:00 AM" (or "…, 09:00" on a 24-hour device).
  static String dateTime(BuildContext context, DateTime t) =>
      '${dayWithYear(t)}, ${time(context, t)}';

  /// "1 Aug – 31 Aug 2026"; the start keeps its year when the years differ.
  static String range(DateTime start, DateTime end) {
    final startFmt = start.year == end.year ? _d : _dy;
    return '${startFmt.format(start)} – ${_dy.format(end)}';
  }

  /// The compact form: "30 Sep" (one day), "22 – 30 Sep" (one month),
  /// "28 Sep – 4 Oct". Outside the current year the year is added
  /// ("22 – 30 Sep 2025", "20 Dec 2025 – 19 Jan 2026").
  static String span(DateTime start, DateTime end, {DateTime? now}) {
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final withYear = !_thisYear(start, now) || !_thisYear(end, now);
    if (sameDay) return (withYear ? _dy : _d).format(start);
    if (start.year != end.year) {
      return '${_dy.format(start)} – ${_dy.format(end)}';
    }
    final endText = (withYear ? _dy : _d).format(end);
    if (start.month == end.month) return '${start.day} – $endText';
    return '${_d.format(start)} – $endText';
  }
}
