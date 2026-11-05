import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/contrast.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/reports/domain/entities/daily_spending_point.dart';
import 'package:monivo/features/reports/domain/entities/monthly_spending_bucket.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/domain/entities/time_analytics.dart';
import 'package:monivo/features/reports/presentation/widgets/bar_chart_card.dart';
import 'package:monivo/features/reports/presentation/widgets/daily_columns_chart.dart';
import 'package:monivo/features/reports/presentation/widgets/planned_vs_actual.dart';
import 'package:monivo/features/reports/presentation/widgets/weekday_rhythm.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String usd(double v) => AppMoney.format(v, currency: 'USD');

  // Monday 5 Oct 2026 onwards.
  List<DailySpendingPoint> week(List<double> amounts) => [
    for (var i = 0; i < amounts.length; i++)
      DailySpendingPoint(date: DateTime(2026, 10, 5 + i), amount: amounts[i]),
  ];

  group('UX-049: the daily chart', () {
    testWidgets('a short column is tappable over the full chart height', (
      tester,
    ) async {
      await pump(
        tester,
        DailyColumnsChart(
          points: week([100, 0, 1, 0, 0, 0, 0]),
          average: 0,
          currency: 'USD',
        ),
      );
      // Wednesday's 1 is a sliver; tap high above it, in its column.
      final x = tester.getCenter(find.text('Wed')).dx;
      final top = tester.getTopLeft(find.byType(BarChart)).dy;
      await tester.tapAt(Offset(x, top + 12));
      await tester.pumpAndSettle();
      expect(find.text('Wed 7 Oct · ${usd(1)}'), findsOneWidget);
    });

    testWidgets('a screen reader can step through the days', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        DailyColumnsChart(
          points: week([100, 20, 0]),
          average: 40,
          currency: 'USD',
        ),
      );
      final chart = find.semantics.byLabel(RegExp('^Daily spending over 3'));
      tester.semantics.increase(chart);
      await tester.pumpAndSettle();
      expect(find.text('Mon 5 Oct · ${usd(100)}'), findsOneWidget);
      tester.semantics.increase(chart);
      await tester.pumpAndSettle();
      expect(find.text('Tue 6 Oct · ${usd(20)}'), findsOneWidget);
      tester.semantics.decrease(chart);
      await tester.pumpAndSettle();
      expect(find.text('Mon 5 Oct · ${usd(100)}'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('day labels name the month where it changes (UX-052)', (
      tester,
    ) async {
      await pump(
        tester,
        DailyColumnsChart(
          points: [
            for (var i = 0; i < 16; i++)
              DailySpendingPoint(
                date: DateTime(2026, 9, 25 + i),
                amount: i + 1.0,
              ),
          ],
          average: 0,
          currency: 'USD',
        ),
      );
      expect(find.text('25 Sep'), findsOneWidget);
      expect(find.text('1 Oct'), findsOneWidget);
    });
  });

  group('the week and month chart', () {
    final october = ReportRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
      period: ReportPeriod.thisMonth,
    );
    List<SpendingBucket> weeks(List<double> amounts) => [
      for (var i = 0; i < amounts.length; i++)
        SpendingBucket(
          label: '',
          amount: amounts[i],
          startDate: DateTime(2026, 9, 28 + 7 * i),
        ),
    ];

    testWidgets('UX-049: a screen reader hears each bar\'s value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        BarChartCard(
          buckets: weeks([30, 10, 20]),
          range: october,
          currency: 'USD',
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Spending by week: 1 – 4 Oct, ${usd(30)}; 5 – 11 Oct, ${usd(10)}; '
          '12 – 18 Oct, ${usd(20)}',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('UX-052: a week cut by the range is labelled by the days it '
        'covers', (tester) async {
      await pump(
        tester,
        BarChartCard(
          buckets: weeks([30, 10, 20]),
          range: october,
          currency: 'USD',
        ),
      );
      expect(find.text('28 Sep'), findsNothing);
      expect(find.text('1 Oct'), findsOneWidget);
      expect(find.textContaining('Highest week: 1 – 4 Oct'), findsOneWidget);
    });

    testWidgets('UX-052: months that span years carry the year', (
      tester,
    ) async {
      await pump(
        tester,
        BarChartCard(
          buckets: [
            for (final (y, m, a) in [
              (2025, 11, 5.0),
              (2025, 12, 9.0),
              (2026, 1, 3.0),
            ])
              SpendingBucket(label: '', amount: a, startDate: DateTime(y, m)),
          ],
          currency: 'USD',
        ),
      );
      expect(find.textContaining('Highest month: Dec 2025'), findsOneWidget);
    });

    testWidgets('UX-052: a long range is grouped by year and its labels '
        'thinned', (tester) async {
      await pump(
        tester,
        BarChartCard(
          buckets: [
            for (var i = 0; i < 40; i++)
              SpendingBucket(
                label: '',
                amount: 10,
                startDate: DateTime(2023, 1 + i),
              ),
          ],
          currency: 'USD',
        ),
      );
      expect(find.text('Spending by year'), findsOneWidget);
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups, hasLength(4));
    });

    testWidgets('UX-052: only every few week labels are drawn', (tester) async {
      await pump(
        tester,
        BarChartCard(
          buckets: [
            for (var i = 0; i < 14; i++)
              SpendingBucket(
                label: '',
                amount: 10.0 + i,
                startDate: DateTime(2026, 1, 5 + 7 * i),
              ),
          ],
          currency: 'USD',
        ),
      );
      expect(find.text('5 Jan'), findsOneWidget);
      expect(find.text('12 Jan'), findsNothing);
    });
  });

  group('UX-051: planned vs actual', () {
    BudgetEntity budget(DateTime end) => BudgetEntity(
      id: 'oct',
      name: 'October',
      monthlyAmount: 1000,
      remainingAmount: 800,
      currency: 'USD',
      startDate: DateTime(2026, 10, 1),
      endDate: end,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

    testWidgets('a running budget ticks today', (tester) async {
      await pump(
        tester,
        PlannedVsActual(
          budget: budget(DateTime(2026, 10, 31)),
          spent: 200,
          now: DateTime(2026, 10, 9),
        ),
      );
      expect(find.textContaining('The tick marks today'), findsOneWidget);
    });

    testWidgets('an ended budget has no "today" tick, and gives the final '
        'share', (tester) async {
      await pump(
        tester,
        PlannedVsActual(
          budget: budget(DateTime(2026, 10, 31)),
          spent: 200,
          now: DateTime(2026, 11, 3),
        ),
      );
      expect(find.textContaining('The tick marks today'), findsNothing);
      expect(find.text('Final: 20% of the plan used.'), findsOneWidget);
    });
  });

  group('UX-070: bars meet the 3:1 non-text floor', () {
    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('weekly rhythm ($name)', (tester) async {
        await pump(
          tester,
          const WeekdayRhythm(
            analytics: TimeAnalytics(
              weekdayBreakdown: [
                WeekdaySpending(weekday: 1, amount: 50, transactionCount: 1),
                WeekdaySpending(weekday: 2, amount: 20, transactionCount: 1),
                WeekdaySpending(weekday: 6, amount: 10, transactionCount: 1),
              ],
              highestSpendingWeekday: 1,
              weekdaySpending: 70,
              weekendSpending: 10,
            ),
            currency: 'USD',
            wholeWeeks: true,
          ),
          theme: theme,
        );
        final bg = theme.scaffoldBackgroundColor;
        final bars = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(WeekdayRhythm),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((b) => (b.decoration as BoxDecoration).color!)
            .toList();
        expect(bars, hasLength(3));
        for (final c in bars) {
          expect(
            Contrast.ratio(Color.alphaBlend(c, bg), bg),
            greaterThanOrEqualTo(3),
          );
        }
        // A day with nothing draws a baseline tick, at 3:1 too.
        final tick = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(const ValueKey('rhythmZero_3')),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(Contrast.ratio(tick.color, bg), greaterThanOrEqualTo(3));
      });

      testWidgets('week and month chart ($name)', (tester) async {
        await pump(
          tester,
          BarChartCard(
            buckets: [
              for (var i = 0; i < 3; i++)
                SpendingBucket(
                  label: '',
                  amount: 10.0 + i,
                  startDate: DateTime(2026, 10, 5 + 7 * i),
                ),
            ],
            currency: 'USD',
          ),
          theme: theme,
        );
        final bg = theme.scaffoldBackgroundColor;
        final chart = tester.widget<BarChart>(find.byType(BarChart));
        for (final g in chart.data.barGroups) {
          final c = g.barRods.single.color!;
          expect(
            Contrast.ratio(Color.alphaBlend(c, bg), bg),
            greaterThanOrEqualTo(3),
          );
        }
      });
    }
  });
}
