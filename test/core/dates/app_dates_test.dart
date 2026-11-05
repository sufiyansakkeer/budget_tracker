import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/dates/date_range_format.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/presentation/widgets/budget_list_items.dart';
import 'package:monivo/features/currency_converter/domain/entities/rate_lookup.dart';
import 'package:monivo/features/currency_converter/presentation/widgets/converter_copy.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_time_picker.dart';

import '../../features/currency_converter/helpers/converter_fakes.dart';

/// UX-093: one date helper, one date order, the year outside the current
/// year, and times in the device's 12/24-hour format.
void main() {
  final now = DateTime(2026, 11, 5, 10);

  group('AppDates', () {
    test('day-first order; the year only outside the current year', () {
      expect(AppDates.day(DateTime(2026, 9, 25), now: now), '25 Sep');
      expect(AppDates.day(DateTime(2025, 9, 25), now: now), '25 Sep 2025');
      expect(AppDates.dayWithYear(DateTime(2026, 9, 25)), '25 Sep 2026');
      expect(AppDates.weekday(DateTime(2026, 11, 5), now: now), 'Thu 5 Nov');
      expect(
        AppDates.weekday(DateTime(2025, 11, 5), now: now),
        'Wed 5 Nov 2025',
      );
      expect(AppDates.fullDay(DateTime(2026, 11, 5)), 'Thu 5 Nov 2026');
      expect(
        AppDates.spokenDay(DateTime(2026, 10, 31), now: now),
        '31 October',
      );
      expect(
        AppDates.spokenDay(DateTime(2025, 10, 31), now: now),
        '31 October 2025',
      );
    });

    test('span: one day, one month, two months, another year', () {
      expect(
        AppDates.span(DateTime(2026, 9, 30), DateTime(2026, 9, 30), now: now),
        '30 Sep',
      );
      expect(
        AppDates.span(DateTime(2026, 9, 22), DateTime(2026, 9, 30), now: now),
        '22 – 30 Sep',
      );
      expect(
        AppDates.span(DateTime(2026, 9, 28), DateTime(2026, 10, 4), now: now),
        '28 Sep – 4 Oct',
      );
      expect(
        AppDates.span(DateTime(2025, 10, 1), DateTime(2025, 10, 31), now: now),
        '1 – 31 Oct 2025',
      );
      expect(
        AppDates.span(DateTime(2025, 12, 20), DateTime(2026, 1, 19), now: now),
        '20 Dec 2025 – 19 Jan 2026',
      );
    });

    test('range always carries the year', () {
      expect(
        AppDates.range(DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
        '1 Oct – 31 Oct 2026',
      );
      expect(
        AppDates.range(DateTime(2025, 12, 20), DateTime(2026, 1, 19)),
        '20 Dec 2025 – 19 Jan 2026',
      );
    });

    testWidgets('times follow the device 12/24-hour setting', (tester) async {
      final t = DateTime(2026, 11, 5, 14, 30);
      for (final use24h in [false, true]) {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(alwaysUse24HourFormat: use24h),
              child: Builder(
                builder: (c) {
                  context = c;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        final time = TimeOfDay.fromDateTime(t).format(context);
        expect(AppDates.time(context, t), time);
        expect(
          AppDates.dateTime(context, t),
          '${AppDates.dayWithYear(t)}, $time',
        );
        expect(time.contains('PM'), !use24h);
      }
    });
  });

  group('call sites', () {
    Future<BuildContext> pump24h(WidgetTester tester, Widget child) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(alwaysUse24HourFormat: true),
            child: Scaffold(
              body: Builder(
                builder: (c) {
                  context = c;
                  return child;
                },
              ),
            ),
          ),
        ),
      );
      return context;
    }

    testWidgets('the expense time field uses the 24-hour setting', (
      tester,
    ) async {
      const time = TimeOfDay(hour: 14, minute: 30);
      final context = await pump24h(
        tester,
        ExpenseTimePicker(time: time, onChanged: (_) {}),
      );
      expect(find.text(time.format(context)), findsOneWidget);
      expect(find.textContaining('PM'), findsNothing);
    });

    testWidgets('the converter reads day-first and in 24-hour time', (
      tester,
    ) async {
      final context = await pump24h(tester, const SizedBox());
      final fetchedAt = DateTime(2025, 9, 25, 18, 3);
      final lookup = RateLookup(
        rate: rateOf(
          'USD',
          'INR',
          '83.1',
          rateDate: DateTime.utc(2025, 9, 25),
          fetchedAt: fetchedAt,
        ),
        origin: RateOrigin.cached,
      );
      expect(
        ConverterCopy.rateDateLabel(DateTime.utc(2025, 9, 25), now),
        AppDates.day(DateTime(2025, 9, 25), now: now),
      );
      expect(
        ConverterCopy.rateDateLabel(DateTime.utc(2025, 9, 25), now),
        isNot(startsWith('Sep')),
      );
      expect(
        ConverterCopy.fetchedLabel(context, lookup, now),
        'Saved ${AppDates.day(fetchedAt, now: now)}, '
        '${AppDates.time(context, fetchedAt)}',
      );
      expect(
        ConverterCopy.fetchedLabel(context, lookup, now),
        isNot(contains('PM')),
      );
    });

    test('a budget from another year shows its year in the list', () {
      final old = BudgetEntity(
        id: 'b',
        name: 'Last year',
        monthlyAmount: 100,
        remainingAmount: 100,
        currency: 'INR',
        startDate: DateTime(2025, 10, 1),
        endDate: DateTime(2025, 10, 31),
        createdAt: DateTime(2025, 10, 1),
        updatedAt: DateTime(2025, 10, 1),
      );
      expect(BudgetPeriodCopy.range(old, now: now), contains('2025'));
      expect(
        BudgetPeriodCopy.range(old, now: now),
        AppDates.span(old.startDate, old.endDate, now: now),
      );
      expect(BudgetPeriodCopy.when(old, now), contains('2025'));
    });
  });
}
