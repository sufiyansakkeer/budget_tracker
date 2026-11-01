import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/dates/calendar_dates.dart';
import 'package:monivo/features/expenses/domain/entities/quick_date_preset.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';

/// Days are counted and stepped on dates. A local day can be 23 or 25 hours
/// long (daylight saving), so Duration arithmetic lands on the wrong date.
/// These cases bite under TZ=America/New_York (8 Mar and 1 Nov 2026).
void main() {
  group('calendar dates', () {
    test('addDays steps whole dates across a daylight-saving change', () {
      expect(DateTime(2026, 3, 9).addDays(-1), DateTime(2026, 3, 8));
      expect(DateTime(2026, 3, 1).addDays(30), DateTime(2026, 3, 31));
      expect(DateTime(2026, 10, 18).addDays(30), DateTime(2026, 11, 17));
      expect(DateTime(2026, 11, 2, 15, 30).addDays(-1), DateTime(2026, 11, 1));
    });

    test('dateOnly drops the time of day', () {
      expect(DateTime(2026, 3, 8, 23, 59).dateOnly, DateTime(2026, 3, 8));
    });

    test('calendarDaysBetween counts dates, not 24-hour blocks', () {
      expect(
        calendarDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 31)),
        30,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 11, 2), DateTime(2026, 11, 1)),
        -1,
      );
      expect(
        calendarDaysBetween(
          DateTime(2026, 2, 28, 23),
          DateTime(2028, 2, 29, 1),
        ),
        731,
      );
    });
  });

  group('sites that used Duration', () {
    test('"Yesterday" the day after the clocks change', () {
      final (start, end) = QuickDatePreset.yesterday.range(
        now: DateTime(2026, 3, 9, 10),
      );
      expect(start, DateTime(2026, 3, 8));
      expect(end, DateTime(2026, 3, 8));
    });

    test('"Last week" across the change is Monday to Sunday', () {
      final (start, end) = QuickDatePreset.lastWeek.range(
        now: DateTime(2026, 3, 11, 10),
      );
      expect(start, DateTime(2026, 3, 2));
      expect(end, DateTime(2026, 3, 8));
    });

    test('a March report counts 31 days', () {
      final range = ReportRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 31),
        period: ReportPeriod.thisMonth,
      );
      expect(range.dayCount, 31);
    });
  });
}
