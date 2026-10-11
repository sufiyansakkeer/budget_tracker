import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/widgets/move_expense_sheet.dart';

import '../expense_test_fakes.dart';

/// UX-005: moving an expense keeps its number and takes the target
/// budget's currency, so ₹300 moved to a dollar budget counted as $300.
void main() {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day - 5);
  final end = DateTime(today.year, today.month, today.day + 5);
  final day = DateTime(today.year, today.month, today.day);

  final budgets = <BudgetEntity>[
    testBudget(id: 'personal', start: start, end: end),
    testBudget(id: 'home', name: 'Home', start: start, end: end),
    testBudget(
      id: 'trip',
      name: 'Trip',
      currency: 'USD',
      start: start,
      end: end,
    ),
  ];
  final expense = ExpenseEntity(
    id: 'e1',
    budgetId: 'personal',
    amount: 300,
    categoryId: 'food',
    date: day,
    time: day.add(const Duration(hours: 12)),
    createdAt: day,
    updatedAt: day,
  );

  Future<List<BudgetEntity?>> open(WidgetTester tester) async {
    final results = <BudgetEntity?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await MoveExpenseSheet.show(
                  context,
                  expense: expense,
                  budgets: budgets,
                ),
              ),
              child: const Text('Move'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('a budget in another currency is listed, disabled, with why', (
    tester,
  ) async {
    final results = await open(tester);

    final trip = tester.widget<ListTile>(
      find.byKey(const Key('moveTarget_trip')),
    );
    expect(trip.enabled, isFalse);
    expect(trip.onTap, isNull);
    expect(
      find.textContaining("Uses USD. Amounts aren't converted"),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('moveTarget_trip')));
    await tester.pumpAndSettle();
    expect(results, isEmpty, reason: 'the sheet stays open');
  });

  testWidgets('a budget in the same currency can be picked, and says which '
      'currency it uses', (tester) async {
    final results = await open(tester);

    expect(find.textContaining('· INR'), findsOneWidget);
    await tester.tap(find.byKey(const Key('moveTarget_home')));
    await tester.pumpAndSettle();

    expect(results.single?.id, 'home');
  });
}
