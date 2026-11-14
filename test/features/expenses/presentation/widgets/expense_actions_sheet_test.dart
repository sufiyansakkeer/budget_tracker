import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_actions_sheet.dart';

void main() {
  final expense = ExpenseEntity(
    id: 'e1',
    budgetId: 'b1',
    amount: 250,
    categoryId: 'food',
    note: 'Pizza',
    date: DateTime(2026, 9, 10),
    time: DateTime(2026, 9, 10, 13),
    createdAt: DateTime(2026, 9, 10),
    updatedAt: DateTime(2026, 9, 10),
  );
  const food = ExpenseCategory(
    id: 'food',
    name: 'Food',
    icon: 'restaurant',
    colorHex: '#FF6B6B',
  );

  Future<ExpenseRowAction? Function()> open(
    WidgetTester tester, {
    bool canMove = true,
    String? billTitle,
  }) async {
    ExpenseRowAction? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await ExpenseActionsSheet.show(
                  context,
                  expense: expense,
                  category: food,
                  currency: 'INR',
                  canMove: canMove,
                  billTitle: billTitle,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets('shows the expense summary and all four actions', (tester) async {
    await open(tester);
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.textContaining('Food'), findsWidgets);
    for (final key in const [
      'expenseAction_edit',
      'expenseAction_duplicate',
      'expenseAction_move',
      'expenseAction_delete',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(find.text('You can undo for a few seconds'), findsOneWidget);
  });

  testWidgets('returns the tapped action', (tester) async {
    final result = await open(tester);
    await tester.tap(find.byKey(const Key('expenseAction_duplicate')));
    await tester.pumpAndSettle();
    expect(result(), ExpenseRowAction.duplicate);
  });

  // UX-060: Move was offered with no other budget to move to.
  testWidgets('hides Move when there is no budget to move to', (tester) async {
    await open(tester, canMove: false);
    expect(find.byKey(const Key('expenseAction_move')), findsNothing);
    expect(find.byKey(const Key('expenseAction_delete')), findsOneWidget);
  });

  // UX-059: a bill payment gave no hint of its bill.
  testWidgets('a bill payment names its bill in the move and delete hints', (
    tester,
  ) async {
    await open(tester, billTitle: 'Rent');
    expect(
      find.descendant(
        of: find.byKey(const Key('expenseAction_move')),
        matching: find.text(
          'Paid bill: Rent. Moving it unlinks it from the bill.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('expenseAction_delete')),
        matching: find.text('Paid bill: Rent. The bill stays paid.'),
      ),
      findsOneWidget,
    );
  });
}
