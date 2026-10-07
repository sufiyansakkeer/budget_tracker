import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_status.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_spending_hero.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_copy.dart';

import 'safe_to_spend_fixtures.dart';

BudgetDailyLimitEntity limit({
  double dailyLimit = 1000,
  double spentToday = 250,
  double weeklyTarget = 7000,
  double weeklySpent = 3000,
  SpendingTargetStatus status = SpendingTargetStatus.onTrack,
}) {
  final over = spentToday > dailyLimit;
  return BudgetDailyLimitEntity(
    budgetId: 'b1',
    budgetName: 'Personal',
    dailyLimit: dailyLimit,
    spentToday: spentToday,
    remainingToday: over ? 0 : dailyLimit - spentToday,
    exceededToday: over ? spentToday - dailyLimit : 0,
    progress: dailyLimit == 0 ? 0 : (spentToday / dailyLimit).clamp(0.0, 1.0),
    isOverLimit: over,
    status: status,
    budgetStatus: BudgetStatus.underBudget,
    budgetUtilization: 0.3,
    monthlyAmount: 30000,
    totalSpent: 9000,
    remainingBudget: 21000,
    remainingDays: 21,
    weeklyTarget: weeklyTarget,
    weeklySpent: weeklySpent,
    weeklyRemaining: (weeklyTarget - weeklySpent).clamp(0, double.infinity),
    weeklyExceeded: weeklySpent > weeklyTarget ? weeklySpent - weeklyTarget : 0,
    weeklyProgress: weeklyTarget == 0
        ? 0
        : (weeklySpent / weeklyTarget).clamp(0.0, 1.0),
    weeklyStatus: SpendingTargetStatus.onTrack,
    currency: 'INR',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 30),
  );
}

void main() {
  Widget harness(BudgetDailyLimitEntity value) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(child: SafeSpendingHero(limit: value)),
    ),
  );

  testWidgets('shows the daily limit, spent and left figures', (tester) async {
    await tester.pumpWidget(harness(limit()));
    await tester.pumpAndSettle();

    expect(find.text("Today's Safe Spending"), findsOneWidget);
    expect(find.text('Spent today'), findsOneWidget);
    expect(find.text('Left today'), findsOneWidget);
    expect(find.text('₹1,000'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    expect(find.text('₹750'), findsOneWidget);
  });

  testWidgets('switches to "Over by" when the limit is exceeded', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(limit(spentToday: 1400, status: SpendingTargetStatus.exceeded)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Over by'), findsOneWidget);
    expect(find.text('Left today'), findsNothing);
  });

  testWidgets('adds a weekly line when there is a weekly share', (
    tester,
  ) async {
    await tester.pumpWidget(harness(limit()));
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('₹3,000 of ₹7,000'), findsOneWidget);
  });

  testWidgets('omits the weekly line when there is no weekly share', (
    tester,
  ) async {
    await tester.pumpWidget(harness(limit(weeklyTarget: 0, weeklySpent: 0)));
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsNothing);
  });

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
      expect(find.text('Groceries · until 31 Aug'), findsOneWidget);
      // weeklyTarget is set on the entry, but the week line is gone.
      expect(find.text('This week'), findsNothing);
      expect(find.text('₹3,000 of ₹7,000'), findsNothing);
    });

    testWidgets('"Over by" uses the error colour whatever the chip says', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(limitFor(safeToSpend(periodSpent: 1400, todaySpent: 1400))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Over by'), findsOneWidget);
      expect(find.text('Left today'), findsNothing);
      expect(find.text('₹400'), findsWidgets);
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_rounded).last);
      expect(icon.color, AppTheme.lightTheme.colorScheme.error);
    });

    testWidgets('OMR 7.600 renders with its fils, never rounded up to 8', (
      tester,
    ) async {
      // 167.200 over 22 days = 7.600 a day.
      final entity = safeToSpend(currency: 'OMR', amount: 167.2);
      expect(entity.dailySafeToSpend, closeTo(7.6, 1e-9));
      await tester.pumpWidget(harness(limitFor(entity)));
      await tester.pumpAndSettle();

      final expected = CurrencyFormatter.format(
        7.6,
        code: 'OMR',
        decimalDigits: 3,
      );
      expect(find.text(expected), findsWidgets);
      expect(
        find.text(CurrencyFormatter.format(8, code: 'OMR', decimalDigits: 0)),
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
