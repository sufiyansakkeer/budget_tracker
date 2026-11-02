import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/dates/calendar_dates.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/services/settle_schedule.dart';

/// Periods and settle-up days (spec §4). Every boundary is a calendar date
/// at local midnight: run this file under TZ=America/New_York too, where
/// 1 Nov 2026 is 25 hours long.
void main() {
  void expectPeriod(
    SettlePeriod? period, {
    required DateTime? start,
    required DateTime? end,
    required DateTime? settleUp,
  }) {
    expect(period, isNotNull);
    expect(period!.start, start, reason: 'start');
    expect(period.end, end, reason: 'end');
    expect(period.settleUp, settleUp, reason: 'settleUp');
  }

  group('every N days', () {
    final every14 = EveryDays(days: 14, anchor: DateTime(2026, 11, 1));

    test('every 14 days from 1 Nov: 14 Nov is in [1 Nov, 14 Nov], '
        'settle-up 15 Nov', () {
      expectPeriod(
        SettleSchedule.periodFor(every14, DateTime(2026, 11, 14)),
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 14),
        settleUp: DateTime(2026, 11, 15),
      );
      // The settle-up day is the first day of the next period.
      expectPeriod(
        SettleSchedule.periodFor(every14, DateTime(2026, 11, 15)),
        start: DateTime(2026, 11, 15),
        end: DateTime(2026, 11, 28),
        settleUp: DateTime(2026, 11, 29),
      );
      expect(
        SettleSchedule.nextSettleUp(every14, DateTime(2026, 11, 14)),
        DateTime(2026, 11, 15),
      );
    });

    test('every 14 days: a purchase before the anchor gets '
        '[18 Oct, 31 Oct]', () {
      expectPeriod(
        SettleSchedule.periodFor(every14, DateTime(2026, 10, 20, 13, 45)),
        start: DateTime(2026, 10, 18),
        end: DateTime(2026, 10, 31),
        settleUp: DateTime(2026, 11, 1),
      );
      expectPeriod(
        SettleSchedule.periodFor(every14, DateTime(2026, 10, 17)),
        start: DateTime(2026, 10, 4),
        end: DateTime(2026, 10, 17),
        settleUp: DateTime(2026, 10, 18),
      );
    });

    test('every 14 days: next settle-up is due today on the settle-up day, '
        'the following one from the day after', () {
      expect(
        SettleSchedule.nextSettleUp(every14, DateTime(2026, 11, 15, 20)),
        DateTime(2026, 11, 15),
      );
      expect(
        SettleSchedule.nextSettleUp(every14, DateTime(2026, 11, 16)),
        DateTime(2026, 11, 29),
      );
      // The anchor is itself the settle-up day of the period before it.
      expect(
        SettleSchedule.nextSettleUp(every14, DateTime(2026, 11, 1)),
        DateTime(2026, 11, 1),
      );
      // Across the US fall-back change: weekly from 25 Oct settles 1 Nov.
      final weekly = EveryDays(days: 7, anchor: DateTime(2026, 10, 25));
      expect(
        SettleSchedule.nextSettleUp(weekly, DateTime(2026, 11, 1, 1, 30)),
        DateTime(2026, 11, 1),
      );
      expect(
        SettleSchedule.nextSettleUp(weekly, DateTime(2026, 11, 2)),
        DateTime(2026, 11, 8),
      );
    });
  });

  group('monthly on a day', () {
    test('monthly day 31: February period ends 27 Feb 2027, '
        'settle-up 28 Feb', () {
      const day31 = MonthlyDay(day: 31);
      expectPeriod(
        SettleSchedule.periodFor(day31, DateTime(2027, 2, 10)),
        start: DateTime(2027, 1, 31),
        end: DateTime(2027, 2, 27),
        settleUp: DateTime(2027, 2, 28),
      );
      // 28 Feb is the clamped day 31, so it starts the next period.
      expectPeriod(
        SettleSchedule.periodFor(day31, DateTime(2027, 2, 28)),
        start: DateTime(2027, 2, 28),
        end: DateTime(2027, 3, 30),
        settleUp: DateTime(2027, 3, 31),
      );
      // Year boundary.
      expectPeriod(
        SettleSchedule.periodFor(day31, DateTime(2026, 12, 31)),
        start: DateTime(2026, 12, 31),
        end: DateTime(2027, 1, 30),
        settleUp: DateTime(2027, 1, 31),
      );
    });

    test('monthly day 15: 15 Mar is the first day of [15 Mar, 14 Apr]', () {
      const day15 = MonthlyDay(day: 15);
      expectPeriod(
        SettleSchedule.periodFor(day15, DateTime(2027, 3, 15)),
        start: DateTime(2027, 3, 15),
        end: DateTime(2027, 4, 14),
        settleUp: DateTime(2027, 4, 15),
      );
      expectPeriod(
        SettleSchedule.periodFor(day15, DateTime(2027, 3, 14)),
        start: DateTime(2027, 2, 15),
        end: DateTime(2027, 3, 14),
        settleUp: DateTime(2027, 3, 15),
      );
    });

    test('monthly day 15: next settle-up is due today on the settle-up day, '
        'the following one from the day after', () {
      const day15 = MonthlyDay(day: 15);
      expect(
        SettleSchedule.nextSettleUp(day15, DateTime(2027, 3, 14, 23)),
        DateTime(2027, 3, 15),
      );
      expect(
        SettleSchedule.nextSettleUp(day15, DateTime(2027, 3, 15, 18)),
        DateTime(2027, 3, 15),
      );
      expect(
        SettleSchedule.nextSettleUp(day15, DateTime(2027, 3, 16)),
        DateTime(2027, 4, 15),
      );
      // Clamped day: day 31 settles on 28 Feb 2027.
      const day31 = MonthlyDay(day: 31);
      expect(
        SettleSchedule.nextSettleUp(day31, DateTime(2027, 2, 28)),
        DateTime(2027, 2, 28),
      );
      expect(
        SettleSchedule.nextSettleUp(day31, DateTime(2027, 3, 1)),
        DateTime(2027, 3, 31),
      );
      // Across the US fall-back change (1 Nov 2026 is 25 hours long).
      const day1 = MonthlyDay(day: 1);
      expect(
        SettleSchedule.nextSettleUp(day1, DateTime(2026, 11, 1, 1, 30)),
        DateTime(2026, 11, 1),
      );
      expect(
        SettleSchedule.nextSettleUp(day1, DateTime(2026, 11, 2)),
        DateTime(2026, 12, 1),
      );
    });
  });

  group('manual date', () {
    test('manual date: before anchor → earlier period settling on anchor; '
        'between → settle on next date; after a passed date → open period', () {
      final manual = ManualDate(
        anchor: DateTime(2026, 11, 1),
        nextSettleDate: DateTime(2026, 11, 20),
      );

      // Before the anchor: one "earlier" period whatever the date.
      final earlier = SettleSchedule.periodFor(manual, DateTime(2026, 10, 25));
      expectPeriod(
        earlier,
        start: null,
        end: DateTime(2026, 10, 31),
        settleUp: DateTime(2026, 11, 1),
      );
      expect(
        SettleSchedule.periodFor(manual, DateTime(2025, 1, 3)),
        earlier,
        reason: 'every purchase before the anchor shares one period',
      );

      // Between anchor and next date.
      expectPeriod(
        SettleSchedule.periodFor(manual, DateTime(2026, 11, 1)),
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 19),
        settleUp: DateTime(2026, 11, 20),
      );
      expectPeriod(
        SettleSchedule.periodFor(manual, DateTime(2026, 11, 19, 22)),
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 19),
        settleUp: DateTime(2026, 11, 20),
      );

      // On or after the settle date: open period, no settle-up day.
      final open = SettleSchedule.periodFor(manual, DateTime(2026, 11, 25));
      expectPeriod(
        open,
        start: DateTime(2026, 11, 20),
        end: null,
        settleUp: null,
      );
      expect(open!.isOpen, isTrue);
      expect(
        SettleSchedule.periodFor(manual, DateTime(2026, 11, 20)),
        open,
        reason: 'the settle date itself starts the open period',
      );

      // Only the before-anchor period is the "earlier" one.
      expect(earlier!.isEarlier, isTrue);
      expect(
        SettleSchedule.periodFor(manual, DateTime(2026, 11, 10))!.isEarlier,
        isFalse,
      );
      expect(open.isEarlier, isFalse);
    });

    test('isEarlier is only the before-anchor manual period', () {
      // No anchor: the current period has no first day but is not earlier.
      final noAnchor = ManualDate(nextSettleDate: DateTime(2026, 11, 20));
      final current = SettleSchedule.periodFor(
        noAnchor,
        DateTime(2026, 11, 2),
      )!;
      expect(current.start, isNull);
      expect(current.isEarlier, isFalse);
      // Nothing set: one open period with no days at all, not earlier.
      final none = SettleSchedule.periodFor(
        const ManualDate(),
        DateTime(2026, 11, 2),
      )!;
      expect(none.start, isNull);
      expect(none.end, isNull);
      expect(none.isEarlier, isFalse);
      // Other rhythms never have an earlier period, even before the anchor.
      final every = EveryDays(days: 14, anchor: DateTime(2026, 11, 1));
      expect(
        SettleSchedule.periodFor(every, DateTime(2026, 9, 1))!.isEarlier,
        isFalse,
      );
      expect(
        SettleSchedule.periodFor(
          const MonthlyDay(day: 15),
          DateTime(2026, 9, 1),
        )!.isEarlier,
        isFalse,
      );
      // Part of equality: same days, different kind.
      expect(
        const SettlePeriod(start: null, isEarlier: true),
        isNot(const SettlePeriod(start: null)),
      );
    });

    test('manual date without an anchor: one period up to the settle date', () {
      final manual = ManualDate(nextSettleDate: DateTime(2026, 11, 20));
      expectPeriod(
        SettleSchedule.periodFor(manual, DateTime(2026, 9, 2)),
        start: null,
        end: DateTime(2026, 11, 19),
        settleUp: DateTime(2026, 11, 20),
      );
      expectPeriod(
        SettleSchedule.periodFor(manual, DateTime(2026, 11, 21)),
        start: DateTime(2026, 11, 20),
        end: null,
        settleUp: null,
      );
    });

    test('manual date: next settle-up is the set date until it has passed', () {
      final manual = ManualDate(
        anchor: DateTime(2026, 11, 1),
        nextSettleDate: DateTime(2026, 11, 20),
      );
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 11, 10)),
        DateTime(2026, 11, 20),
      );
      // The settle-up day itself is still upcoming, not passed.
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 11, 20, 18)),
        DateTime(2026, 11, 20),
      );
      // Passed and no new date: nothing advances automatically.
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 11, 21)),
        isNull,
      );
      expect(
        SettleSchedule.nextSettleUp(const ManualDate(), DateTime(2026, 11, 21)),
        isNull,
      );
    });

    test('manual date nextSettleUp: before the anchor it is the anchor (the '
        'earlier period settles there)', () {
      final manual = ManualDate(
        anchor: DateTime(2026, 11, 1),
        nextSettleDate: DateTime(2026, 11, 20),
      );
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 10, 25, 23)),
        DateTime(2026, 11, 1),
      );
      // The day after the anchor: the set date.
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 11, 2)),
        DateTime(2026, 11, 20),
      );
    });

    test('manual date nextSettleUp without an anchor: the set date through '
        'that day, then nothing', () {
      final manual = ManualDate(nextSettleDate: DateTime(2026, 11, 20));
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 9, 2)),
        DateTime(2026, 11, 20),
      );
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 11, 20, 23, 59)),
        DateTime(2026, 11, 20),
      );
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 11, 21)),
        isNull,
      );
    });

    test('manual date nextSettleUp with an anchor but no date: nothing', () {
      final manual = ManualDate(anchor: DateTime(2026, 11, 1));
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 11, 2)),
        isNull,
      );
      // Before the anchor the earlier period still settles on the anchor.
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 10, 30)),
        DateTime(2026, 11, 1),
      );
    });

    test('manual date nextSettleUp across the US fall-back day', () {
      final manual = ManualDate(nextSettleDate: DateTime(2026, 11, 1));
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 11, 1, 1, 30)),
        DateTime(2026, 11, 1),
      );
      expect(
        SettleSchedule.nextSettleUp(manual, DateTime(2026, 11, 2, 0, 30)),
        isNull,
      );
    });
  });

  test('on demand: no period, nextSettleUp null', () {
    const onDemand = OnDemand();
    expect(SettleSchedule.periodFor(onDemand, DateTime(2026, 11, 2)), isNull);
    expect(
      SettleSchedule.nextSettleUp(onDemand, DateTime(2026, 11, 2)),
      isNull,
    );
  });

  test('US DST day 2026-11-01 stays in its calendar period', () {
    // 1 Nov 2026 is 25 hours long in New York: a period start stepped with
    // Duration from 25 Oct lands on 7 Nov 23:00 instead of 8 Nov.
    final weekly = EveryDays(days: 7, anchor: DateTime(2026, 10, 25));
    for (final moment in [
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 1, 0, 30),
      DateTime(2026, 11, 1, 1, 30),
      DateTime(2026, 11, 1, 23, 59),
    ]) {
      expectPeriod(
        SettleSchedule.periodFor(weekly, moment),
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 7),
        settleUp: DateTime(2026, 11, 8),
      );
    }
    expectPeriod(
      SettleSchedule.periodFor(weekly, DateTime(2026, 11, 8, 0, 30)),
      start: DateTime(2026, 11, 8),
      end: DateTime(2026, 11, 14),
      settleUp: DateTime(2026, 11, 15),
    );
    expectPeriod(
      SettleSchedule.periodFor(weekly, DateTime(2026, 10, 31, 23, 59)),
      start: DateTime(2026, 10, 25),
      end: DateTime(2026, 10, 31),
      settleUp: DateTime(2026, 11, 1),
    );

    const monthly = MonthlyDay(day: 1);
    expectPeriod(
      SettleSchedule.periodFor(monthly, DateTime(2026, 11, 1, 1, 30)),
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 30),
      settleUp: DateTime(2026, 12, 1),
    );
    expectPeriod(
      SettleSchedule.periodFor(monthly, DateTime(2026, 10, 31, 23, 59)),
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
      settleUp: DateTime(2026, 11, 1),
    );

    // Spring forward too (8 Mar 2026 is 23 hours long): Duration stepping
    // from 1 Mar lands on 10 Mar 01:00.
    final every3 = EveryDays(days: 3, anchor: DateTime(2026, 3, 1));
    expectPeriod(
      SettleSchedule.periodFor(every3, DateTime(2026, 3, 9, 0, 30)),
      start: DateTime(2026, 3, 7),
      end: DateTime(2026, 3, 9),
      settleUp: DateTime(2026, 3, 10),
    );
    expectPeriod(
      SettleSchedule.periodFor(every3, DateTime(2026, 3, 10, 0, 30)),
      start: DateTime(2026, 3, 10),
      end: DateTime(2026, 3, 12),
      settleUp: DateTime(2026, 3, 13),
    );
  });

  group('settle-up day boundaries: the day before, the day, the day after', () {
    /// nextSettleUp at the first and last moment of [day].
    void expectNext(SettleRhythm rhythm, DateTime day, DateTime? expected) {
      for (final moment in [
        day,
        DateTime(day.year, day.month, day.day, 23, 59),
      ]) {
        expect(
          SettleSchedule.nextSettleUp(rhythm, moment),
          expected,
          reason: '$rhythm at $moment',
        );
      }
    }

    /// The day before [settleUp] reads it, the day itself reads it
    /// ("today"), the day after reads [following].
    void expectAround(
      SettleRhythm rhythm,
      DateTime settleUp,
      DateTime? following,
    ) {
      expectNext(rhythm, settleUp.addDays(-1), settleUp);
      expectNext(rhythm, settleUp, settleUp);
      expectNext(rhythm, settleUp.addDays(1), following);
    }

    test('every 3 days across a month end (settle-ups 31 Oct, 3 Nov)', () {
      final every3 = EveryDays(days: 3, anchor: DateTime(2026, 10, 28));
      expectAround(every3, DateTime(2026, 10, 31), DateTime(2026, 11, 3));
      expectAround(every3, DateTime(2026, 11, 3), DateTime(2026, 11, 6));
      // The last day of a period is the day before its settle-up day.
      expectPeriod(
        SettleSchedule.periodFor(every3, DateTime(2026, 11, 2, 23, 59)),
        start: DateTime(2026, 10, 31),
        end: DateTime(2026, 11, 2),
        settleUp: DateTime(2026, 11, 3),
      );
    });

    test('every day: every day is a settle-up day', () {
      final daily = EveryDays(days: 1, anchor: DateTime(2026, 11, 1));
      var day = DateTime(2026, 10, 25);
      for (var i = 0; i < 14; i++, day = day.addDays(1)) {
        expectNext(daily, day, day);
        expectPeriod(
          SettleSchedule.periodFor(daily, day),
          start: day,
          end: day,
          settleUp: day.addDays(1),
        );
      }
    });

    test('monthly day 31 in a 30-day month: 30 Apr is the settle-up day', () {
      const day31 = MonthlyDay(day: 31);
      expectAround(day31, DateTime(2027, 4, 30), DateTime(2027, 5, 31));
      expectPeriod(
        SettleSchedule.periodFor(day31, DateTime(2027, 4, 29)),
        start: DateTime(2027, 3, 31),
        end: DateTime(2027, 4, 29),
        settleUp: DateTime(2027, 4, 30),
      );
      expectPeriod(
        SettleSchedule.periodFor(day31, DateTime(2027, 4, 30)),
        start: DateTime(2027, 4, 30),
        end: DateTime(2027, 5, 30),
        settleUp: DateTime(2027, 5, 31),
      );
    });

    test('monthly day 29, 30 and 31 in February: 28 Feb, or 29 Feb in a '
        'leap year', () {
      for (final d in [29, 30, 31]) {
        final rhythm = MonthlyDay(day: d);
        // 2027 is not a leap year.
        expectAround(rhythm, DateTime(2027, 2, 28), DateTime(2027, 3, d));
        // 2028 is: 29 Feb exists, and 28 Feb is the day before.
        expectAround(rhythm, DateTime(2028, 2, 29), DateTime(2028, 3, d));
        expectNext(rhythm, DateTime(2028, 2, 28), DateTime(2028, 2, 29));
      }
      // Day 29 is not clamped in a leap year, and the January period of
      // day 30 ends the day before the clamped day.
      expectPeriod(
        SettleSchedule.periodFor(
          const MonthlyDay(day: 29),
          DateTime(2028, 2, 1),
        ),
        start: DateTime(2028, 1, 29),
        end: DateTime(2028, 2, 28),
        settleUp: DateTime(2028, 2, 29),
      );
      expectPeriod(
        SettleSchedule.periodFor(
          const MonthlyDay(day: 30),
          DateTime(2027, 2, 27),
        ),
        start: DateTime(2027, 1, 30),
        end: DateTime(2027, 2, 27),
        settleUp: DateTime(2027, 2, 28),
      );
    });

    test('monthly day 1 at a month and year end', () {
      const day1 = MonthlyDay(day: 1);
      expectAround(day1, DateTime(2026, 12, 1), DateTime(2027, 1, 1));
      expectAround(day1, DateTime(2027, 1, 1), DateTime(2027, 2, 1));
      expectAround(day1, DateTime(2028, 3, 1), DateTime(2028, 4, 1));
    });

    test('pick a date: the day before and the day read the date, the day '
        'after reads nothing (no automatic next date)', () {
      final manual = ManualDate(
        anchor: DateTime(2026, 11, 1),
        nextSettleDate: DateTime(2026, 11, 30),
      );
      expectAround(manual, DateTime(2026, 11, 30), null);
      final leap = ManualDate(nextSettleDate: DateTime(2028, 2, 29));
      expectAround(leap, DateTime(2028, 2, 29), null);
    });

    test('on demand: no settle-up on any day', () {
      var day = DateTime(2028, 2, 26);
      for (var i = 0; i < 5; i++, day = day.addDays(1)) {
        expectNext(const OnDemand(), day, null);
      }
    });

    test(
      'every monthly day 1–31 over two years (leap year included): '
      'periods tile the calendar and the settle-up day is the clamped day',
      () {
        for (var d = 1; d <= 31; d++) {
          final rhythm = MonthlyDay(day: d);
          var day = DateTime(2027, 1, 1);
          while (day.year < 2029) {
            final period = SettleSchedule.periodFor(rhythm, day)!;
            final start = period.start!;
            final settleUp = period.settleUp!;
            expect(
              !day.isBefore(start) && !day.isAfter(period.end!),
              isTrue,
              reason: 'day $d: $day in $period',
            );
            expect(period.end, settleUp.addDays(-1), reason: 'day $d: $day');
            final monthLength = DateTime(
              settleUp.year,
              settleUp.month + 1,
              0,
            ).day;
            expect(
              settleUp.day,
              d < monthLength ? d : monthLength,
              reason: 'day $d: $day',
            );
            // The settle-up day starts the next period.
            expect(
              SettleSchedule.periodFor(rhythm, settleUp)!.start,
              settleUp,
              reason: 'day $d: $day',
            );
            expect(
              SettleSchedule.nextSettleUp(rhythm, day),
              start == day ? day : settleUp,
              reason: 'day $d: $day',
            );
            day = day.addDays(1);
          }
        }
      },
    );

    test('every N days over a year: the settle-up day reads today, the day '
        'after reads N days later', () {
      for (final n in [1, 2, 7, 14, 30, 31, 365]) {
        final rhythm = EveryDays(days: n, anchor: DateTime(2027, 3, 14));
        var day = DateTime(2027, 1, 1);
        while (day.year < 2028) {
          final next = SettleSchedule.nextSettleUp(rhythm, day)!;
          final period = SettleSchedule.periodFor(rhythm, day)!;
          expect(calendarDaysBetween(period.start!, period.settleUp!), n);
          if (period.start == day) {
            expect(next, day, reason: 'every $n: $day');
            expect(
              SettleSchedule.nextSettleUp(rhythm, day.addDays(1)),
              day.addDays(n),
              reason: 'every $n: day after $day',
            );
          } else {
            expect(next, period.settleUp, reason: 'every $n: $day');
          }
          day = day.addDays(1);
        }
      }
    });
  });
}
