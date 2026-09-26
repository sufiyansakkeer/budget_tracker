import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_event.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_state.dart';

import 'app_harness.dart';

/// The history list must stay put: a search must settle after its debounce,
/// a refresh must not throw away pages the user has scrolled through, and a
/// swiped-away row must leave the list at once.
void main() {
  late AppHarness app;

  setUp(() async => app = await AppHarness.create());
  tearDown(() => app.dispose());

  Future<ExpenseHistoryState> loaded(ExpenseHistoryBloc bloc) =>
      bloc.stream.firstWhere((s) => s.status == ExpenseHistoryStatus.loaded);

  Future<void> seed(String budgetId, int count) async {
    final now = DateTime.now();
    for (var i = 0; i < count; i++) {
      await app.expenseRepository.createExpense(
        app.newExpense(
          budgetId: budgetId,
          amount: 10.0 + i,
          note: i.isEven ? 'coffee $i' : 'lunch $i',
          date: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: i % 7)),
        ),
      );
    }
  }

  test('a search settles after the debounce and stops emitting', () async {
    final budget = await app.addBudget();
    await seed(budget.id, 5);
    final bloc = app.historyBloc();
    addTearDown(bloc.close);
    bloc.add(const ExpenseHistoryLoad());
    await loaded(bloc);

    final emissions = <ExpenseHistoryState>[];
    final sub = bloc.stream.listen(emissions.add);
    addTearDown(sub.cancel);

    bloc.add(const ExpenseHistorySearchChanged('coffee'));
    await Future<void>.delayed(
      ExpenseHistoryBloc.searchDebounce + const Duration(milliseconds: 50),
    );
    expect(bloc.state.visibleExpenses.length, 3);
    final settled = emissions.length;

    // Nothing else may arrive once the debounce has fired.
    await Future<void>.delayed(ExpenseHistoryBloc.searchDebounce * 3);
    expect(emissions.length, settled);
  });

  test('a refresh keeps the pages the user has already loaded', () async {
    final budget = await app.addBudget();
    await seed(budget.id, 45);
    final bloc = app.historyBloc();
    addTearDown(bloc.close);
    bloc.add(const ExpenseHistoryLoad());
    final first = await loaded(bloc);
    expect(first.loadedExpenses.length, 20);

    bloc.add(const ExpenseHistoryLoadMore());
    await loaded(bloc);
    expect(bloc.state.loadedExpenses.length, 40);

    bloc.add(const ExpenseHistoryRefresh());
    final refreshed = await loaded(bloc);
    expect(refreshed.loadedExpenses.length, 40);
    expect(refreshed.hasMore, isTrue);

    // A new sort starts again from the top.
    bloc.add(const ExpenseHistorySortChanged(ExpenseSortOption.highestAmount));
    await loaded(bloc);
    expect(bloc.state.loadedExpenses.length, 20);
  });

  test('a removed expense leaves the list immediately', () async {
    final budget = await app.addBudget();
    await seed(budget.id, 4);
    final bloc = app.historyBloc();
    addTearDown(bloc.close);
    bloc.add(const ExpenseHistoryLoad());
    final state = await loaded(bloc);
    final victim = state.loadedExpenses.first;

    bloc.add(ExpenseHistoryExpenseRemoved(victim.id));
    final after = await loaded(bloc);
    expect(after.loadedExpenses.map((e) => e.id), isNot(contains(victim.id)));
    expect(after.summary.totalExpenses, 3);
    expect(after.allExpenses.length, 3);
  });
}
