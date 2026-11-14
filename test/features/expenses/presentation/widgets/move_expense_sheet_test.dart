import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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
    testBudget(
      id: 'last',
      name: 'Last month',
      start: DateTime(today.year, today.month, today.day - 60),
      end: DateTime(today.year, today.month, today.day - 30),
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

  Future<List<BudgetEntity?>> open(
    WidgetTester tester, {
    String? billTitle,
  }) async {
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
                  billTitle: billTitle,
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

    expect(
      find.descendant(
        of: find.byKey(const Key('moveTarget_home')),
        matching: find.textContaining('· INR'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('moveTarget_home')));
    await tester.pumpAndSettle();

    expect(results.single?.id, 'home');
  });
  // Pay later spec §5: a purchase on a tab can't move to a budget in
  // another currency. Its budget is in the tab's currency, so the sheet's
  // same-currency rule already blocks it; nothing tab-specific is needed.
  testWidgets('a tab purchase can only move within its tab\'s currency', (
    tester,
  ) async {
    final results = await open(tester);

    expect(
      tester.widget<ListTile>(find.byKey(const Key('moveTarget_trip'))).enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('moveTarget_trip')));
    await tester.pumpAndSettle();
    expect(results, isEmpty);

    await tester.tap(find.byKey(const Key('moveTarget_home')));
    await tester.pumpAndSettle();
    expect(results.single?.currency, 'INR');
  });

  // UX-060: a budget whose period misses the expense's date was offered,
  // then refused after the pick with a long SnackBar.
  testWidgets('a budget whose period misses the expense date is listed, '
      'disabled, with why', (tester) async {
    final results = await open(tester);

    final last = tester.widget<ListTile>(
      find.byKey(const Key('moveTarget_last')),
    );
    expect(last.enabled, isFalse);
    expect(last.onTap, isNull);
    expect(
      find.textContaining(
        'This expense is dated ${DateFormat('d MMM yyyy').format(day)}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('moveTarget_last')));
    await tester.pumpAndSettle();
    expect(results, isEmpty, reason: 'the sheet stays open');
    expect(find.byType(SnackBar), findsNothing);
  });

  // UX-059: moving a bill payment unlinks it from the bill, unannounced.
  testWidgets('a bill payment says which bill, and that moving unlinks it', (
    tester,
  ) async {
    await open(tester, billTitle: 'Rent');
    expect(
      find.textContaining(
        'Paid bill: Rent. Moving it unlinks it from the bill.',
      ),
      findsOneWidget,
    );
  });
}
