import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_event.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_state.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_event.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_state.dart';

import 'app_harness.dart';

/// End-to-end coverage of the expense lifecycle: every step goes through the
/// real use cases and repositories into SQLite, and the effects are read back
/// through the history and dashboard BLoCs.
void main() {
  late AppHarness app;

  setUp(() async => app = await AppHarness.create());
  tearDown(() => app.dispose());

  Future<ExpenseState> waitForSuccess(ExpenseBloc bloc) {
    return bloc.stream.firstWhere(
      (s) =>
          s.status == ExpenseBlocStatus.success ||
          s.status == ExpenseBlocStatus.error,
    );
  }

  test(
    'creating an expense reduces the budget and shows up everywhere',
    () async {
      final budget = await app.addBudget(amount: 30000);
      final expenses = app.expenseBloc();
      addTearDown(expenses.close);

      expenses.add(
        ExpenseCreate(
          app.newExpense(budgetId: budget.id, amount: 1200, note: 'Groceries'),
        ),
      );
      final result = await waitForSuccess(expenses);

      expect(result.status, ExpenseBlocStatus.success);
      expect(result.lastAction, ExpenseAction.created);
      expect(await app.storedRemaining(budget.id), 28800);

      // The history BLoC, built separately, sees the row.
      final history = app.historyBloc();
      addTearDown(history.close);
      history.add(const ExpenseHistoryLoad());
      final loaded = await history.stream.firstWhere(
        (s) => s.status == ExpenseHistoryStatus.loaded,
      );
      expect(loaded.visibleExpenses.single.note, 'Groceries');
      expect(loaded.summary.totalAmount, 1200);

      // So does the dashboard.
      final dashboard = app.dashboardBloc();
      addTearDown(dashboard.close);
      dashboard.add(const DashboardLoadData());
      final dash = await dashboard.stream.firstWhere(
        (s) => s is DashboardLoaded,
      );
      final loadedDash = dash as DashboardLoaded;
      expect(loadedDash.budgetSummary.totalSpent, 1200);
      expect(loadedDash.budgetSummary.remainingBudget, 28800);
      expect(loadedDash.recentExpenses.single.note, 'Groceries');
    },
  );

  test('editing an expense re-derives the remaining amount', () async {
    final budget = await app.addBudget(amount: 10000);
    final expenses = app.expenseBloc();
    addTearDown(expenses.close);

    final expense = app.newExpense(budgetId: budget.id, amount: 500);
    expenses.add(ExpenseCreate(expense));
    await waitForSuccess(expenses);
    expect(await app.storedRemaining(budget.id), 9500);

    expenses.add(
      ExpenseUpdate(expense.copyWith(amount: 2000, note: 'Corrected')),
    );
    final updated = await waitForSuccess(expenses);

    expect(updated.lastAction, ExpenseAction.updated);
    expect(await app.storedRemaining(budget.id), 8000);
    final stored = await app.expenseRepository.getExpenseById(expense.id);
    expect(stored!.amount, 2000);
    expect(stored.note, 'Corrected');
  });

  test('deleting an expense gives the money back and can be undone', () async {
    final budget = await app.addBudget(amount: 5000);
    final expenses = app.expenseBloc();
    addTearDown(expenses.close);

    final expense = app.newExpense(
      budgetId: budget.id,
      amount: 750,
      note: 'Taxi',
      tags: ['work'],
    );
    expenses.add(ExpenseCreate(expense));
    await waitForSuccess(expenses);
    expect(await app.storedRemaining(budget.id), 4250);

    expenses.add(ExpenseDelete(expense.id));
    final deleted = await waitForSuccess(expenses);
    expect(deleted.lastAction, ExpenseAction.deleted);
    expect(await app.expenseRepository.getExpenseById(expense.id), isNull);
    expect(await app.storedRemaining(budget.id), 5000);

    // Undo restores the same row, with its note and tags.
    expenses.add(ExpenseRestore(deleted.lastDeleted!));
    final restored = await waitForSuccess(expenses);
    expect(restored.lastAction, ExpenseAction.restored);

    final back = await app.expenseRepository.getExpenseById(expense.id);
    expect(back, isNotNull);
    expect(back!.note, 'Taxi');
    expect(back.tags, ['work']);
    expect(await app.storedRemaining(budget.id), 4250);
  });

  test('moving an expense to another budget moves the money too', () async {
    final from = await app.addBudget(id: 'from', name: 'From', amount: 10000);
    final to = await app.addBudget(
      id: 'to',
      name: 'To',
      amount: 8000,
      makeActive: false,
    );
    final expenses = app.expenseBloc();
    addTearDown(expenses.close);

    final expense = app.newExpense(budgetId: from.id, amount: 1000);
    expenses.add(ExpenseCreate(expense));
    await waitForSuccess(expenses);
    expect(await app.storedRemaining(from.id), 9000);

    expenses.add(ExpenseUpdate(expense.copyWith(budgetId: to.id)));
    await waitForSuccess(expenses);

    expect(
      await app.storedRemaining(from.id),
      10000,
      reason: 'the old budget is credited back',
    );
    expect(await app.storedRemaining(to.id), 7000);
  });

  test('an expense cannot be created without a budget', () async {
    final expenses = app.expenseBloc();
    addTearDown(expenses.close);

    expenses.add(ExpenseCreate(app.newExpense(budgetId: '', amount: 100)));
    final result = await waitForSuccess(expenses);

    expect(result.status, ExpenseBlocStatus.error);
    expect(result.message, contains('No active budget'));
  });

  test('search and filters run over what was actually stored', () async {
    final budget = await app.addBudget(amount: 20000);
    final expenses = app.expenseBloc();
    addTearDown(expenses.close);

    for (final (note, amount, category) in const [
      ('Pizza night', 800.0, 'food'),
      ('Petrol', 2500.0, 'fuel'),
      ('Cinema', 400.0, 'entertainment'),
    ]) {
      expenses.add(
        ExpenseCreate(
          app.newExpense(
            budgetId: budget.id,
            amount: amount,
            categoryId: category,
            note: note,
          ),
        ),
      );
      await waitForSuccess(expenses);
    }

    final history = app.historyBloc();
    addTearDown(history.close);
    history.add(const ExpenseHistoryLoad());
    var state = await history.stream.firstWhere(
      (s) => s.status == ExpenseHistoryStatus.loaded,
    );
    expect(state.visibleExpenses.length, 3);
    expect(state.summary.totalAmount, 3700);

    // Search is debounced: the query lands immediately, the recompute after
    // ExpenseHistoryBloc.searchDebounce.
    history.add(const ExpenseHistorySearchChanged('petrol'));
    await Future<void>.delayed(ExpenseHistoryBloc.searchDebounce * 2);
    state = history.state;
    expect(state.query, 'petrol');
    expect(state.visibleExpenses.single.note, 'Petrol');
    expect(state.summary.totalAmount, 2500);
  });
}
