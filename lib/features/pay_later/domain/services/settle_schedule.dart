import 'dart:math' as math;

import '../../../../core/dates/calendar_dates.dart';
import '../entities/settle_rhythm.dart';

/// Periods and settle-up days for a [SettleRhythm] (spec §4).
///
/// Works on calendar dates (local midnight) only: the time of day of every
/// input is ignored and days are stepped with [CalendarDates], never with
/// `Duration`, so a 23- or 25-hour day can't move a boundary.
abstract final class SettleSchedule {
  /// The period [date] falls in; null for [OnDemand].
  static SettlePeriod? periodFor(SettleRhythm rhythm, DateTime date) {
    final day = date.dateOnly;
    return switch (rhythm) {
      OnDemand() => null,
      EveryDays(:final days, :final anchor) => _everyDays(
        math.max(days, 1),
        anchor.dateOnly,
        day,
      ),
      MonthlyDay(day: final dayOfMonth) => _monthly(
        dayOfMonth.clamp(1, 31),
        day,
      ),
      ManualDate(:final nextSettleDate, :final anchor) => _manual(
        nextSettleDate?.dateOnly,
        anchor?.dateOnly,
        day,
      ),
    };
  }

  /// The earliest settle-up day on or after [today]; null for [OnDemand].
  /// On a settle-up day that is the day itself ("due today"); from the day
  /// after, the next one. A [ManualDate] gives its date through that day
  /// and null once it has passed (nothing advances automatically) or when
  /// none is set.
  static DateTime? nextSettleUp(SettleRhythm rhythm, DateTime today) {
    final day = today.dateOnly;
    switch (rhythm) {
      case OnDemand():
        return null;
      case EveryDays() || MonthlyDay():
        // A period's first day is the settle-up day of the one before it.
        final period = periodFor(rhythm, day)!;
        return period.start == day ? day : period.settleUp;
      case ManualDate(:final nextSettleDate):
        final settleUp = periodFor(rhythm, day)!.settleUp;
        if (settleUp != null) return settleUp;
        final next = nextSettleDate?.dateOnly;
        return next != null && next == day ? next : null;
    }
  }

  /// `[anchor + kN, anchor + (k+1)N − 1]` for the k holding [day], also for
  /// k < 0. Settle-up day = first day of the next period.
  static SettlePeriod _everyDays(int days, DateTime anchor, DateTime day) {
    final offset = calendarDaysBetween(anchor, day);
    // Floor division: a day before the anchor belongs to period k < 0.
    final k = offset >= 0 ? offset ~/ days : -((-offset + days - 1) ~/ days);
    final start = anchor.addDays(k * days);
    final settleUp = start.addDays(days);
    return SettlePeriod(
      start: start,
      end: settleUp.addDays(-1),
      settleUp: settleUp,
    );
  }

  /// From [dayOfMonth] of one month to the day before [dayOfMonth] of the
  /// next, each clamped to its month's length. Settle-up day = the next
  /// month's day.
  static SettlePeriod _monthly(int dayOfMonth, DateTime day) {
    final thisMonth = _clampedDay(day.year, day.month, dayOfMonth);
    final DateTime start;
    final DateTime settleUp;
    if (day.isBefore(thisMonth)) {
      start = _clampedDay(day.year, day.month - 1, dayOfMonth);
      settleUp = thisMonth;
    } else {
      start = thisMonth;
      settleUp = _clampedDay(day.year, day.month + 1, dayOfMonth);
    }
    return SettlePeriod(
      start: start,
      end: settleUp.addDays(-1),
      settleUp: settleUp,
    );
  }

  /// [dayOfMonth] of [month] (which may be 0 or 13: DateTime normalises it),
  /// clamped to that month's last day.
  static DateTime _clampedDay(int year, int month, int dayOfMonth) {
    final first = DateTime(year, month);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, math.min(dayOfMonth, lastDay));
  }

  /// Before [anchor]: one "earlier" period settling on [anchor]. From
  /// [anchor] (no first day when none) to the day before [next]: the
  /// current period settling on [next]. On or after [next] (or with no date
  /// set): an open period with no settle-up day. A missing first day is a
  /// null start.
  static SettlePeriod _manual(DateTime? next, DateTime? anchor, DateTime day) {
    if (anchor != null && day.isBefore(anchor)) {
      return SettlePeriod(
        start: null,
        end: anchor.addDays(-1),
        settleUp: anchor,
        isEarlier: true,
      );
    }
    if (next != null && day.isBefore(next)) {
      return SettlePeriod(start: anchor, end: next.addDays(-1), settleUp: next);
    }
    // Open: starts at the later of the two dates that are set.
    final DateTime? openStart;
    if (next == null) {
      openStart = anchor;
    } else if (anchor == null || anchor.isBefore(next)) {
      openStart = next;
    } else {
      openStart = anchor;
    }
    return SettlePeriod(start: openStart);
  }
}
