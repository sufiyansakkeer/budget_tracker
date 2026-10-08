import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_spending_hero.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_copy.dart';

import 'safe_to_spend_fixtures.dart';

void main() {
  Widget harness(BudgetDailyLimitEntity value) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(child: SafeSpendingHero(limit: value)),
    ),
  );

  group('with safe-to-spend', () {
    for (final entry in runningStatusFixtures.entries) {
      testWidgets('shows the ${entry.key} status chip', (tester) async {
        final entity = entry.value();
        expect(entity.status.name, entry.key);
        await tester.pumpWidget(harness(limitFor(entity)));
        await tester.pumpAndSettle();

        expect(
          find.text(SafeToSpendCopy.statusLabel(entity.status)),
          findsOneWidget,
        );
        // The legacy status labels never appear.
        expect(find.text('Near limit'), findsNothing);
        expect(find.text('Over limit'), findsNothing);
      });
    }

    test('labels every status distinctly', () {
      final labels = SafeToSpendStatus.values
          .map(SafeToSpendCopy.statusLabel)
          .toSet();
      expect(labels, hasLength(SafeToSpendStatus.values.length));
      expect(labels, contains('Spend carefully'));
      expect(labels, contains("Over today's amount"));
    });

    testWidgets('shows the daily amount, spent and left, without the week '
        'line', (tester) async {
      await tester.pumpWidget(
        harness(limitFor(safeToSpend(periodSpent: 250, todaySpent: 250))),
      );
      await tester.pumpAndSettle();

      expect(find.text("Today's Safe Spending"), findsOneWidget);
      expect(find.text('₹1,000'), findsOneWidget);
      expect(find.text('₹250'), findsOneWidget);
      expect(find.text('₹750'), findsOneWidget);
      // The budget behind the figure: what is left, the days to go and
      // today's place in the period (calendar days, today included).
      expect(find.text('₹21,750 left of ₹22,000'), findsOneWidget);
      expect(find.text('22 days left'), findsOneWidget);
      expect(find.text('Day 10 of 31'), findsOneWidget);
      // The budget's name is the screen title now, not repeated here.
      expect(find.text('Groceries · until 31 Aug'), findsNothing);
      // weeklyTarget is set on the entry, but the week line is gone.
      expect(find.text('This week'), findsNothing);
      expect(find.text('₹3,000 of ₹7,000'), findsNothing);
    });

    testWidgets('"Over by" uses the caution colour, never the critical red', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(limitFor(safeToSpend(periodSpent: 1400, todaySpent: 1400))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Over by'), findsOneWidget);
      expect(find.text('Left today'), findsNothing);
      expect(find.text('₹400'), findsWidgets);
      // Going over today's amount is recoverable, so it is caution (amber);
      // red is reserved for money already gone.
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_rounded).last);
      final tokens = AppTheme.lightTheme.extension<AppColorTokens>()!;
      expect(icon.color, tokens.warning);
      expect(icon.color, isNot(AppTheme.lightTheme.colorScheme.error));
    });

    testWidgets('an overspend says how much less each later day gets', (
      tester,
    ) async {
      // 1,400 spent of 1,000 today, 22 days left: 400 over, spread over 21.
      await tester.pumpWidget(
        harness(limitFor(safeToSpend(periodSpent: 1400, todaySpent: 1400))),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("That's about ₹19.05 less on each of the next 21 days."),
        findsOneWidget,
      );
      // The spread replaces the generic over-today explanation, so the hero
      // does not say the same thing twice.
      expect(
        find.textContaining("more than today's safe amount"),
        findsNothing,
      );
    });

    testWidgets('offers the working only when it can be opened', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SafeSpendingHero(
                limit: limitFor(safeToSpend()),
                onShowWorking: () => opened++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("How it's worked out"));
      expect(opened, 1);

      await tester.pumpWidget(harness(limitFor(safeToSpend())));
      await tester.pumpAndSettle();
      expect(find.text("How it's worked out"), findsNothing);
    });

    testWidgets('OMR 7.600 renders with its fils, never rounded up to 8', (
      tester,
    ) async {
      // 167.200 over 22 days = 7.600 a day.
      final entity = safeToSpend(currency: 'OMR', amount: 167.2);
      expect(entity.dailySafeToSpend, closeTo(7.6, 1e-9));
      await tester.pumpWidget(harness(limitFor(entity)));
      await tester.pumpAndSettle();

      // The figure keeps its fils (with a left-to-right mark after the
      // Arabic-script symbol, so the digits stay after it).
      final expected = AppMoney.format(7.6, currency: 'OMR', floored: true);
      expect(expected, endsWith('7.600'));
      expect(find.text(expected), findsWidgets);
      expect(
        find.text(AppMoney.format(8, currency: 'OMR', floored: true)),
        findsNothing,
      );
    });

    testWidgets('a fractional safe amount is floored, never rounded up', (
      tester,
    ) async {
      // 1,000 / 3 days on 29 Aug = 333.333… → ₹333.33 (not ₹333.34/₹333).
      final entity = safeToSpend(amount: 1000, today: DateTime(2026, 8, 29));
      await tester.pumpWidget(harness(limitFor(entity)));
      await tester.pumpAndSettle();

      expect(find.text('₹333.33'), findsNWidgets(2)); // amount + left today
    });

    testWidgets('bill payments today get a caption and are not spent today', (
      tester,
    ) async {
      final entity = safeToSpend(
        amount: 37000,
        periodSpent: 15000,
        todaySpent: 15000,
        committedInPeriod: 15000,
        committedToday: 15000,
      );
      expect(entity.dailySafeToSpend, closeTo(1000, 1e-9));
      await tester.pumpWidget(harness(limitFor(entity)));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Bill payments today (₹15,000) are already counted in your bills "
          "and don't use today's amount.",
        ),
        findsOneWidget,
      );
      expect(find.text('₹0'), findsOneWidget); // Spent today
      expect(find.text('₹1,000'), findsNWidgets(2)); // amount + left today
    });

    testWidgets('shows one explanation line for the top reason', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          limitFor(
            safeToSpend(
              commitments: [bill('rent', 25000, DateTime(2026, 8, 25))],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Bills and money set aside are ₹3,000 more than what's left in "
          'this budget.',
        ),
        findsOneWidget,
      );
      // Lower-priority reasons are not shown as a second line.
      expect(find.textContaining('lower because of bills'), findsNothing);
    });

    testWidgets('reads the figures as one merged label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(limitFor(safeToSpend(periodSpent: 250, todaySpent: 250))),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          RegExp(
            r"^Today's Safe Spending, ₹1,000\. On track\. Groceries, until "
            r'31 August\. Spent today ₹250, left today ₹750\.',
          ),
        ),
        findsOneWidget,
      );
      // The info button stays separately reachable.
      expect(find.byTooltip("About Today's Safe Spending"), findsOneWidget);
      handle.dispose();
    });
  });
  group('narrow screens with large text (review: title row overflowed)', () {
    for (final width in [320.0, 360.0]) {
      for (final entry in runningStatusFixtures.entries) {
        testWidgets('${entry.key} at ${width.toInt()}dp and 200% text', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: const TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    // The dashboard's 16dp page gutter.
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SafeSpendingHero(limit: limitFor(entry.value())),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // The status label is shown whole, and the info button keeps its
          // full tap target.
          final label = SafeToSpendCopy.statusLabel(entry.value().status);
          expect(find.text(label), findsOneWidget);
          final info = find.byType(IconButton);
          expect(info, findsOneWidget);
          expect(tester.getSize(info).width, greaterThanOrEqualTo(48));
        });
      }
    }
  });
}
