import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_for_budgets_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/page_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/search_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/sort_expenses_usecase.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_event.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_state.dart';
import 'package:monivo/features/expenses/presentation/history/pages/expense_history_screen.dart';
import 'package:monivo/features/pay_later/domain/entities/purchase_change_impact.dart';

import '../expense_test_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';

/// Swipe-delete of purchases on a Pay later tab (spec §5, "Delete a
/// purchase").
void main() {
  late MemoryExpenseRepository expenses;
  late StubBudgetRepository budgets;
  late FakeTabPurchaseUseCase purchases;

  final at = DateTime(2026, 8, 5, 13);
  final lunch = ExpenseEntity(
    id: 'a',
    budgetId: 'personal',
    amount: 120,
    categoryId: 'food',
    note: 'Lunch',
    date: DateTime(2026, 8, 5),
    time: at,
    createdAt: at,
    updatedAt: at,
  );

  const paid = PurchaseChangeImpact(
    paidOnIt: 50,
    movesTo: [],
    becomesCredit: 50,
    currency: 'INR',
  );
  const unpaid = PurchaseChangeImpact(
    paidOnIt: 0,
    movesTo: [],
    becomesCredit: 0,
    currency: 'INR',
  );

  setUp(() {
    expenses = MemoryExpenseRepository()..store[lunch.id] = lunch;
    budgets = StubBudgetRepository([
      testBudget(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31)),
    ]);
    purchases = FakeTabPurchaseUseCase()..tabIds['a'] = 't1';
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final history = ExpenseHistoryBloc(
      getExpensesUseCase: GetExpensesUseCase(repository: expenses),
      getExpensesForBudgetsUseCase: GetExpensesForBudgetsUseCase(
        repository: expenses,
      ),
      getCategoriesUseCase: GetCategoriesUseCase(repository: expenses),
      searchExpensesUseCase: const SearchExpensesUseCase(),
      filterExpensesUseCase: const FilterExpensesUseCase(),
      sortExpensesUseCase: const SortExpensesUseCase(),
      calculateExpenseSummaryUseCase: const CalculateExpenseSummaryUseCase(),
      pageExpensesUseCase: const PageExpensesUseCase(pageSize: 20),
      budgetRepository: budgets,
    );
    addTearDown(history.close);
    final expenseBloc = memoryExpenseBloc(
      expenses,
      budgets,
      tabPurchases: purchases,
    );
    addTearDown(expenseBloc.close);
    history.add(const ExpenseHistoryLoad());
    await history.stream.firstWhere(
      (s) => s.status == ExpenseHistoryStatus.loaded,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ExpenseHistoryBloc>.value(value: history),
            BlocProvider<ExpenseBloc>.value(value: expenseBloc),
          ],
          child: const ExpenseHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('dismiss_a')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  testWidgets('history swipe on a paid tab purchase asks first; Cancel keeps '
      'the row', (tester) async {
    purchases.impactFor = (q) => q.deleting ? paid : null;
    await pump(tester);

    await swipe(tester);
    expect(find.text('Delete this purchase?'), findsOneWidget);
    expect(purchases.impactQueries.single.deleting, isTrue);

    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);
    expect(purchases.calls, isNot(contains('delete:a')));
  });

  testWidgets('a confirmed delete of a paid tab purchase offers no Undo', (
    tester,
  ) async {
    purchases.impactFor = (q) => q.deleting ? paid : null;
    await pump(tester);

    await swipe(tester);
    await tester.tap(inDialog('Delete'));
    await tester.pumpAndSettle();

    expect(purchases.calls, contains('delete:a'));
    expect(find.text('Expense deleted'), findsOneWidget);
    expect(find.byKey(const Key('undoDeleteAction')), findsNothing);
  });

  testWidgets('history swipe on an unpaid tab purchase deletes at once, and '
      'Undo puts it back on its tab', (tester) async {
    purchases.impactFor = (q) => unpaid;
    await pump(tester);

    await swipe(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(purchases.calls, contains('delete:a'));

    await tester.tap(find.byKey(const Key('undoDeleteAction')));
    await tester.pumpAndSettle();
    expect(purchases.calls, contains('restore:a:t1'));
  });

  testWidgets("a payments check that fails keeps the row and says so", (
    tester,
  ) async {
    purchases.impactError = Exception('database is locked');
    await pump(tester);

    await swipe(tester);

    expect(find.text('Lunch'), findsOneWidget);
    expect(purchases.calls, isNot(contains('delete:a')));
    expect(
      // Neutral (M5): the read failed, so it isn't known to be on a tab.
      find.text("Couldn't delete the expense. Try again."),
      findsOneWidget,
    );
  });
  testWidgets('a second long-press delete while payments are being checked '
      'does nothing', (tester) async {
    final read = Completer<void>();
    purchases.impactGate = read.future;
    purchases.impactFor = (q) => q.deleting ? paid : null;
    await pump(tester);

    Future<void> longPressDelete() async {
      await tester.longPress(find.text('Lunch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expenseAction_delete')));
      await tester.pumpAndSettle();
    }

    await longPressDelete();
    await longPressDelete();
    read.complete();
    await tester.pumpAndSettle();

    expect(purchases.impactQueries, hasLength(1));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(inDialog('Delete'));
    await tester.pumpAndSettle();
    expect(purchases.calls.where((c) => c == 'delete:a'), hasLength(1));
  });
}
