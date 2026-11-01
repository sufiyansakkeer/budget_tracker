/// Calendar-day arithmetic.
///
/// A local day is 23 or 25 hours long when the clocks change, so stepping
/// with `Duration(days: n)` or counting with `difference().inDays` can land
/// on the wrong date. These work on dates instead.
extension CalendarDates on DateTime {
  /// This moment's date, at local midnight.
  DateTime get dateOnly => DateTime(year, month, day);

  /// The date [days] calendar days later (earlier when negative), at local
  /// midnight.
  DateTime addDays(int days) => DateTime(year, month, day + days);
}

/// Whole calendar days from the date of [from] to the date of [to]
/// (negative when [to] is earlier). The time of day is ignored, and so is
/// daylight saving: 8 Mar 2026 → 9 Mar 2026 is 1 in every time zone.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
