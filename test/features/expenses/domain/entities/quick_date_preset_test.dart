import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/expenses/domain/entities/quick_date_preset.dart';
import 'package:monivo/core/dates/date_range_format.dart';

void main() {
  // Wednesday 16 September 2026.
  final now = DateTime(2026, 9, 16, 14, 30);

  group('QuickDatePreset.range', () {
    test('today and yesterday', () {
      expect(QuickDatePreset.today.range(now: now), (
        DateTime(2026, 9, 16),
        DateTime(2026, 9, 16),
      ));
      expect(QuickDatePreset.yesterday.range(now: now), (
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 15),
      ));
    });

    test('weeks start on Monday', () {
      expect(QuickDatePreset.thisWeek.range(now: now), (
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 16),
      ));
      expect(QuickDatePreset.lastWeek.range(now: now), (
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 13),
      ));
    });

    test('months and year', () {
      expect(QuickDatePreset.thisMonth.range(now: now), (
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 30),
      ));
      expect(QuickDatePreset.lastMonth.range(now: now), (
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 31),
      ));
      expect(QuickDatePreset.thisYear.range(now: now), (
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
      ));
    });

    test('last month across a year boundary', () {
      final jan = DateTime(2027, 1, 10);
      expect(QuickDatePreset.lastMonth.range(now: jan), (
        DateTime(2026, 12, 1),
        DateTime(2026, 12, 31),
      ));
    });

    test('of() recognises a matching filter and nothing else', () {
      final f = ExpenseHistoryFilter(
        dateFrom: DateTime(2026, 9, 7),
        dateTo: DateTime(2026, 9, 13),
      );
      expect(QuickDatePreset.of(f, now: now), QuickDatePreset.lastWeek);
      final custom = ExpenseHistoryFilter(
        dateFrom: DateTime(2026, 9, 2),
        dateTo: DateTime(2026, 9, 5),
      );
      expect(QuickDatePreset.of(custom, now: now), isNull);
    });
  });

  group('custom range chip label (AppDates.span)', () {
    test('single day, same year, different years', () {
      expect(
        AppDates.span(DateTime(2026, 3, 12), DateTime(2026, 3, 12), now: now),
        '12 Mar',
      );
      expect(
        AppDates.span(DateTime(2026, 3, 12), DateTime(2026, 3, 15), now: now),
        '12 – 15 Mar',
      );
      expect(
        AppDates.span(DateTime(2025, 12, 30), DateTime(2026, 1, 2), now: now),
        '30 Dec 2025 – 2 Jan 2026',
      );
    });
  });
}
