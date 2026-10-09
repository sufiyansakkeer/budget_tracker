import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_breakdown_card.dart';

import 'safe_to_spend_fixtures.dart';

void main() {
  Widget harness(SafeToSpendEntity value) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: SafeToSpendBreakdownCard(safeToSpend: value),
      ),
    ),
  );

  final rent = bill(
    'rent',
    12000,
    DateTime(2026, 8, 5),
    title: 'Rent',
    overdue: true,
  );
  final phone = bill('phone', 500, DateTime(2026, 8, 20), title: 'Phone');

  group('deductions', () {
    testWidgets('adds up remaining − bills − kept aside − savings goal', (
      tester,
    ) async {
      final entity = safeToSpend(
        amount: 30000,
        periodSpent: 8000,
        commitments: [rent, phone],
        reserved: 2000,
        savings: 1500,
      );
      await tester.pumpWidget(harness(entity));

      expect(find.text('Remaining in budget'), findsOneWidget);
      expect(find.text('₹22,000'), findsOneWidget);
      expect(find.text('Bills due by 31 Aug (2)'), findsOneWidget);
      expect(find.text('₹12,500'), findsOneWidget);
      expect(find.text('Kept aside'), findsOneWidget);
      expect(find.text('₹2,000'), findsOneWidget);
      expect(find.text('Savings goal'), findsOneWidget);
      expect(find.text('₹1,500'), findsOneWidget);
      expect(find.text('Free to spend until 31 Aug'), findsOneWidget);
      expect(find.text('₹6,000'), findsOneWidget);
    });

    testWidgets('"Not set" (no amount chosen) is distinct from ₹0', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final entity = safeToSpend(commitments: [phone], reserved: 0);
      await tester.pumpWidget(harness(entity));

      // Kept aside was set to 0; the savings goal was never set.
      expect(find.text('Not set'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
      expect(find.bySemanticsLabel('Kept aside, minus ₹0'), findsOneWidget);
      expect(find.bySemanticsLabel('Savings goal, not set'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('bills that could not be loaded read "Unavailable"', (
      tester,
    ) async {
      await tester.pumpWidget(harness(safeToSpend(billsUnavailable: true)));

      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('No bills due this period'), findsNothing);
      expect(find.textContaining('Bills due by'), findsNothing);
    });

    testWidgets('no bills at all reads "No bills due this period" with ₹0', (
      tester,
    ) async {
      await tester.pumpWidget(harness(safeToSpend()));

      expect(find.text('No bills due this period'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
      expect(find.text('Unavailable'), findsNothing);
      expect(find.text('Not set'), findsNWidgets(2));
    });

    testWidgets('the bills row expands to the deducted occurrences', (
      tester,
    ) async {
      await tester.pumpWidget(harness(safeToSpend(commitments: [rent, phone])));
      expect(find.text('Rent · 5 Aug · ₹12,000'), findsNothing);

      await tester.tap(find.text('Bills due by 31 Aug (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Rent · 5 Aug · ₹12,000'), findsOneWidget);
      expect(find.text('Phone · 20 Aug · ₹500'), findsOneWidget);
      // Only the overdue occurrence is marked.
      expect(find.text('Overdue'), findsOneWidget);

      await tester.tap(find.text('Bills due by 31 Aug (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Rent · 5 Aug · ₹12,000'), findsNothing);
    });

    testWidgets('a shortfall reads "{amount} short", not ₹0', (tester) async {
      final entity = safeToSpend(
        commitments: [bill('rent', 25000, DateTime(2026, 8, 25))],
      );
      expect(entity.status, SafeToSpendStatus.overcommitted);
      await tester.pumpWidget(harness(entity));

      expect(find.text('₹3,000 short'), findsOneWidget);
    });

    testWidgets('OMR lines keep their fils so they add up on screen', (
      tester,
    ) async {
      // 10.600 − 0.600 = 10.000: never "11 − 1 = 10".
      final entity = safeToSpend(
        currency: 'OMR',
        amount: 10.6,
        commitments: [bill('water', 0.6, DateTime(2026, 8, 20))],
      );
      await tester.pumpWidget(harness(entity));

      String omr(double v, int digits) =>
          CurrencyFormatter.format(v, code: 'OMR', decimalDigits: digits);
      expect(find.text(omr(10.6, 3)), findsOneWidget);
      expect(find.text(omr(0.6, 3)), findsOneWidget);
      expect(find.text(omr(10, 0)), findsOneWidget);
      expect(find.text(omr(11, 0)), findsNothing);
      expect(find.text(omr(1, 0)), findsNothing);
    });
  });

  group('forecast', () {
    testWidgets('asks for more days while history is short', (tester) async {
      // 2 Aug: one completed day of the three needed.
      await tester.pumpWidget(
        harness(
          safeToSpend(
            today: DateTime(2026, 8, 2),
            periodSpent: 300,
            todaySpent: 0,
          ),
        ),
      );

      expect(find.text('Forecast'), findsOneWidget);
      expect(find.text('Ready after 2 more days of spending'), findsOneWidget);
      expect(find.textContaining('Average a day'), findsNothing);
    });

    testWidgets('waits for a first expense when nothing is spent', (
      tester,
    ) async {
      await tester.pumpWidget(harness(safeToSpend()));

      expect(
        find.text('Ready after your first expense in this budget.'),
        findsOneWidget,
      );
    });

    testWidgets('projects a reliable pace that lasts', (tester) async {
      // 1,000 a day over 9 days of a 44,000 budget.
      final entity = safeToSpend(amount: 44000, periodSpent: 9000);
      expect(entity.forecast!.isReliable, isTrue);
      await tester.pumpWidget(harness(entity));

      expect(find.text('Average a day so far'), findsOneWidget);
      expect(find.text('₹1,000'), findsOneWidget);
      expect(find.text('Projected spending by 31 Aug'), findsOneWidget);
      expect(find.text('₹31,000'), findsOneWidget);
      expect(find.text('Projected left on 31 Aug'), findsOneWidget);
      expect(find.text('₹13,000'), findsOneWidget);
      expect(find.textContaining('runs out'), findsNothing);
    });

    testWidgets('says when free money runs out at the current pace', (
      tester,
    ) async {
      final entity = runningStatusFixtures['budgetAtRisk']!();
      expect(entity.forecast!.exhaustionDate, isNotNull);
      await tester.pumpWidget(harness(entity));

      expect(find.textContaining('Free money runs out around'), findsOneWidget);
    });

    testWidgets('shows no forecast before the period starts', (tester) async {
      await tester.pumpWidget(
        harness(safeToSpend(today: DateTime(2026, 7, 25))),
      );

      expect(find.text('Forecast'), findsNothing);
    });
  });
}
