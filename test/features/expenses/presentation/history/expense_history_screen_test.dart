import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_for_budgets_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/page_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/search_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/sort_expenses_usecase.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_event.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_state.dart';
import 'package:monivo/features/expenses/presentation/history/pages/expense_history_screen.dart';

import '../expense_test_fakes.dart';

ExpenseEntity _expense(
  String id,
  double amount, {
  String budgetId = 'personal',
  String categoryId = 'food',
  String? note,
  int day = 5,
}) {
  final at = DateTime(2026, 8, day, 13);
  return ExpenseEntity(
    id: id,
    budgetId: budgetId,
    amount: amount,
    categoryId: categoryId,
    note: note,
    date: DateTime(2026, 8, day),
    time: at,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  late MemoryExpenseRepository expenses;
  late StubBudgetRepository budgets;

  setUp(() {
    expenses = MemoryExpenseRepository();
    budgets = StubBudgetRepository([
      testBudget(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31)),
    ]);
  });

  void seed(List<ExpenseEntity> list) {
    for (final e in list) {
      expenses.store[e.id] = e;
    }
  }

  ExpenseHistoryBloc bloc() => ExpenseHistoryBloc(
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

  Future<ExpenseHistoryBloc> pump(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double textScale = 1,
    Future<void> Function(ExpenseHistoryBloc bloc)? prepare,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final history = bloc();
    addTearDown(history.close);
    history.add(const ExpenseHistoryLoad());
    await history.stream.firstWhere(
      (s) => s.status == ExpenseHistoryStatus.loaded,
    );
    if (prepare != null) await prepare(history);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: BlocProvider<ExpenseHistoryBloc>.value(
            value: history,
            child: const ExpenseHistoryScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return history;
  }

  testWidgets('amounts are in the active budget\'s currency (review: '
      'every amount showed ₹)', (tester) async {
    budgets.budgets['personal'] = testBudget(
      currency: 'OMR',
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );
    seed([_expense('a', 7.5, note: 'Lunch'), _expense('b', 2.25)]);
    await pump(tester);

    expect(find.text(AppMoney.format(7.5, currency: 'OMR')), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('a day header says what was spent and how many, quietly', (
    tester,
  ) async {
    seed([_expense('a', 120), _expense('b', 230, categoryId: 'fuel')]);
    await pump(tester);

    expect(find.text('Spent ₹350'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    // The summary is type, not a card: the total and the count on one line.
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('2 expenses · avg ₹175'), findsOneWidget);
  });

  testWidgets('the budget menu replaces the mode switch', (tester) async {
    seed([_expense('a', 120)]);
    await pump(tester);

    expect(find.byType(SegmentedButton<ExpenseViewMode>), findsNothing);
    expect(find.text('Personal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('viewModeToggle')));
    await tester.pumpAndSettle();
    expect(find.text('Switch budget'), findsOneWidget);
    expect(find.text('View budgets together'), findsOneWidget);
  });

  testWidgets('the header scrolls away with the list', (tester) async {
    seed([
      for (var i = 0; i < 30; i++) _expense('e$i', 10.0 + i, day: 1 + i % 20),
    ]);
    await pump(tester);
    expect(find.text('Expenses').hitTestable(), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Expenses').hitTestable(), findsNothing);
  });

  testWidgets('a combined view of two currencies totals each one '
      '(review: they were added together under ₹)', (tester) async {
    budgets.budgets['muscat'] = testBudget(
      id: 'muscat',
      name: 'Muscat',
      currency: 'OMR',
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );
    seed([
      _expense('a', 500),
      _expense('b', 300, day: 6),
      _expense('c', 4.5, budgetId: 'muscat'),
    ]);
    await pump(
      tester,
      prepare: (history) async {
        history.add(const ExpenseHistoryToggleViewMode());
        await history.stream.firstWhere((s) => s.allBudgets.length == 2);
        history.add(
          const ExpenseHistorySetBudgetSelection(['personal', 'muscat']),
        );
        history.add(const ExpenseHistoryApplyCombinedView());
        await history.stream.firstWhere(
          (s) =>
              s.status == ExpenseHistoryStatus.loaded &&
              s.summaryByCurrency.length == 2,
        );
      },
    );

    // One total per currency, never ₹804.50.
    expect(find.text('₹800'), findsOneWidget);
    expect(find.text(AppMoney.format(4.5, currency: 'OMR')), findsWidgets);
    expect(find.textContaining('804'), findsNothing);
    // 5 Aug mixes the two currencies, so it shows a count without a total;
    // 6 Aug is all rupees and keeps its total.
    expect(find.text('Spent ₹300'), findsOneWidget);
    expect(find.textContaining('Spent ₹500'), findsNothing);
    expect(find.text('Across 2 budgets · 3 expenses'), findsOneWidget);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
      seed([
        _expense('a', 123456.75, note: 'A long note about a big purchase'),
        _expense('b', 99, categoryId: 'entertainment'),
      ]);
      await pump(tester, size: Size(width, 800), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
