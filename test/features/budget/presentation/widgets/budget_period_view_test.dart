import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/presentation/widgets/budget_period_view.dart';

import '../../../dashboard/presentation/widgets/safe_to_spend_fixtures.dart';

void main() {
  BudgetEntity budgetOf(SafeToSpendEntity e) => BudgetEntity(
    id: e.budgetId,
    name: e.budgetName,
    monthlyAmount: e.budgetAmount,
    remainingAmount: e.availableBalance,
    currency: e.currency,
    startDate: e.startDate,
    endDate: e.endDate,
    createdAt: e.startDate,
    updatedAt: e.startDate,
  );

  for (final (label, e) in [
    // Almost nothing spent: the free block is wide and short.
    (
      'wide free block, 27 days',
      safeToSpend(today: DateTime(2026, 8, 5), periodSpent: 10),
    ),
    // Most spent: the free block is narrow.
    ('narrow free block', safeToSpend(periodSpent: 17000)),
  ]) {
    testWidgets('every day of free money is a square inside its block '
        '($label)', (tester) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: BudgetPeriodView(
                budget: budgetOf(e),
                e: e,
                expenseCount: 1,
                others: const [],
                onShowWorking: () {},
                onChangeTarget: () {},
                onOpenBills: () {},
                onOpenSpent: () {},
                onAllBudgets: () {},
                onOpenOther: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final block = tester.getRect(find.byKey(const Key('money_map_free')));
      for (var i = 0; i < e.remainingDays; i++) {
        final square = find.byKey(Key('money_map_day_$i'));
        expect(square, findsOneWidget, reason: 'day $i');
        final r = tester.getRect(square);
        expect(r.bottom, lessThanOrEqualTo(block.bottom), reason: 'day $i');
        expect(r.right, lessThanOrEqualTo(block.right), reason: 'day $i');
      }
    });
  }
}
