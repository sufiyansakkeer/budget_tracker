import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/presentation/widgets/budget_chips.dart';
import 'package:monivo/features/dashboard/presentation/widgets/target_ring.dart';

import 'safe_to_spend_fixtures.dart';

void main() {
  final household = limitFor(
    safeToSpend(
      budgetId: 'h',
      name: 'Household',
      periodSpent: 250,
      todaySpent: 250,
    ),
  );
  final personal = limitFor(
    safeToSpend(budgetId: 'p', name: 'Personal', amount: 11000),
  );

  Widget harness(
    List<BudgetDailyLimitEntity> limits, {
    ValueChanged<String>? onSelect,
    VoidCallback? onOpenActive,
  }) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: BudgetChips(
        limits: limits,
        activeBudgetId: 'h',
        onSelect: onSelect ?? (_) {},
        onOpenActive: onOpenActive ?? () {},
      ),
    ),
  );

  testWidgets('one chip per running budget: name and amount a day', (
    tester,
  ) async {
    await tester.pumpWidget(harness([household, personal]));
    await tester.pumpAndSettle();

    expect(find.text('Household'), findsOneWidget);
    expect(find.text('₹1,000 a day'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('₹500 a day'), findsOneWidget);
    // Each carries a small ring of its own day.
    expect(find.byType(MiniTargetRing), findsNWidgets(2));
  });

  testWidgets('the active budget is selected; another switches to it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final picked = <String>[];
    await tester.pumpWidget(
      harness([household, personal], onSelect: picked.add),
    );
    await tester.pumpAndSettle();

    final active = tester.getSemantics(find.byKey(const Key('budget_chip_h')));
    expect(active.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(active.label, contains('Household'));
    final other = tester.getSemantics(find.byKey(const Key('budget_chip_p')));
    expect(other.hasFlag(SemanticsFlag.isSelected), isFalse);

    await tester.tap(find.text('Personal'));
    // Only a change of budget is reported as one.
    expect(picked, ['p']);
    handle.dispose();
  });

  testWidgets('the selected chip opens the budget menu', (tester) async {
    var opened = 0;
    final picked = <String>[];
    await tester.pumpWidget(
      harness(
        [household, personal],
        onSelect: picked.add,
        onOpenActive: () => opened++,
      ),
    );
    await tester.tap(find.text('Household'));
    expect(opened, 1);
    expect(picked, isEmpty);
  });

  testWidgets('a single budget is one chip: the screen\'s title (blueprint)', (
    tester,
  ) async {
    await tester.pumpWidget(harness([household]));
    expect(find.byKey(const Key('budget_chip_h')), findsOneWidget);
  });

  testWidgets('pills: the selected one filled with the brand container', (
    tester,
  ) async {
    await tester.pumpWidget(harness([household, personal]));
    final scheme = AppTheme.lightTheme.colorScheme;
    Material chip(String id) => tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(Key('budget_chip_$id')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(chip('h').color, scheme.primaryContainer);
    expect(chip('h').shape, isA<StadiumBorder>());
    expect(chip('p').color, Colors.transparent);
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(const Key('budget_chip_h')),
              matching: find.byType(MiniTargetRing),
            ),
          )
          .width,
      30,
    );
  });
}
