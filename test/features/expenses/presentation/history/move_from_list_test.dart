import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
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
import 'package:monivo/features/expenses/presentation/widgets/expense_undo.dart';

import '../../../../helpers/pay_later_fakes.dart';
import '../expense_test_fakes.dart';

/// UX-060: a move from the list said "Expense updated" (details said
/// "Moved to …"), neither with Undo, and Move was offered with nowhere to
/// move to.
void main() {
  late MemoryExpenseRepository expenses;
  late StubBudgetRepository budgets;
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

  setUp(() async {
    await getIt.reset();
    expenses = MemoryExpenseRepository()..store[lunch.id] = lunch;
    budgets = StubBudgetRepository([
      testBudget(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31)),
    ]);
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(
        repository: budgets,
        reconcileTabs: FakeReconcileTabUseCase(),
      ),
    );
    ExpenseUndo.blocFactory = () => memoryExpenseBloc(expenses, budgets);
  });
  tearDown(() async {
    ExpenseUndo.blocFactory = () => getIt<ExpenseBloc>();
    await getIt.reset();
  });

  Future<void> pump(WidgetTester tester) async {
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
    final expenseBloc = memoryExpenseBloc(expenses, budgets);
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

  testWidgets('a move says where to, and Undo moves it back', (tester) async {
    budgets.budgets['home'] = testBudget(
      id: 'home',
      name: 'Home',
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );
    await pump(tester);

    await tester.longPress(find.text('Lunch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseAction_move')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveTarget_home')));
    await tester.pumpAndSettle();

    expect(expenses.store['a']!.budgetId, 'home');
    expect(find.text('Moved to Home'), findsOneWidget);
    expect(find.text('Expense updated'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(expenses.store['a']!.budgetId, 'personal');
  });

  testWidgets('Move is not offered with no other budget', (tester) async {
    await pump(tester);

    await tester.longPress(find.text('Lunch'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expenseAction_edit')), findsOneWidget);
    expect(find.byKey(const Key('expenseAction_move')), findsNothing);
  });
}
