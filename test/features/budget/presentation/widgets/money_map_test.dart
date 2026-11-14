import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/presentation/widgets/money_map.dart';

import '../../../dashboard/presentation/widgets/safe_to_spend_fixtures.dart';

void main() {
  Widget harness(SafeToSpendEntity e) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: 360, child: MoneyMap(safeToSpend: e)),
      ),
    ),
  );

  // 22,000: 2,000 spent, a 1,500 bill, 500 kept aside, a 1,000 savings goal,
  // so 17,000 is free.
  SafeToSpendEntity split() => safeToSpend(
    periodSpent: 2000,
    commitments: [bill('rent', 1500, DateTime(2026, 8, 20))],
    reserved: 500,
    savings: 1000,
  );

  testWidgets('names the whole amount and where each part of it is', (
    tester,
  ) async {
    await tester.pumpWidget(harness(split()));

    expect(find.text('Where the ₹22,000 is'), findsOneWidget);
    for (final (label, value) in const [
      ('Spent', '₹2,000'),
      ('Bills due', '₹1,500'),
      ('Kept aside', '₹500'),
      ('Savings goal', '₹1,000'),
      ('Free to spend', '₹17,000'),
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(find.text(value), findsOneWidget, reason: value);
    }
  });

  testWidgets('the bar splits in proportion to the amounts', (tester) async {
    await tester.pumpWidget(harness(split()));

    double width(String part) =>
        tester.getSize(find.byKey(Key('money_map_$part'))).width;
    expect(width('free') / width('spent'), closeTo(17000 / 2000, 0.05));
    expect(width('bills') / width('kept'), closeTo(1500 / 500, 0.05));
  });

  testWidgets('parts that are not set say so and draw nothing', (
    tester,
  ) async {
    await tester.pumpWidget(harness(safeToSpend(periodSpent: 2000)));

    expect(find.text('Not set'), findsNWidgets(2)); // kept aside, savings
    expect(find.byKey(const Key('money_map_kept')), findsNothing);
    expect(find.byKey(const Key('money_map_savings')), findsNothing);
    expect(find.text('None'), findsOneWidget); // no bills due
  });

  testWidgets('bills beyond what is left: free reads short, in red', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        safeToSpend(commitments: [bill('rent', 25000, DateTime(2026, 8, 25))]),
      ),
    );

    expect(find.text('₹3,000 short'), findsOneWidget);
    final short = tester.widget<Text>(find.text('₹3,000 short'));
    expect(short.style?.color, AppTheme.lightTheme.colorScheme.error);
    expect(find.byKey(const Key('money_map_free')), findsNothing);
  });

  testWidgets('one label per row for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(split()));
    expect(find.bySemanticsLabel(RegExp(r'^Free to spend, ')), findsOneWidget);
    handle.dispose();
  });
}
