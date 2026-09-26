import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_event.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_state.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_event.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_state.dart';

import 'app_harness.dart';

/// Reports read the same rows the expense feature writes: this drives the
/// whole path from an expense being saved to a rendered report snapshot.
void main() {
  late AppHarness app;

  setUp(() async => app = await AppHarness.create());
  tearDown(() => app.dispose());

  Future<void> spend({
    required String budgetId,
    required double amount,
    required String categoryId,
    required DateTime date,
    required ExpenseBloc bloc,
  }) async {
    bloc.add(
      ExpenseCreate(
        app.newExpense(
          budgetId: budgetId,
          amount: amount,
          categoryId: categoryId,
          date: date,
        ),
      ),
    );
    await bloc.stream.firstWhere(
      (s) =>
          s.status == ExpenseBlocStatus.success ||
          s.status == ExpenseBlocStatus.error,
    );
  }

  Future<ReportsState> loadReport(ReportsBloc bloc, ReportPeriod period) {
    bloc.add(ReportsPeriodChanged(period));
    return bloc.stream.firstWhere(
      (s) =>
          s.data != null &&
          s.period == period &&
          s.status == ReportsStatus.loaded,
    );
  }

  test('a report totals and breaks down what was actually spent', () async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final budget = await app.addBudget(
      amount: 40000,
      startDate: monthStart,
      endDate: DateTime(now.year, now.month + 1, 0),
    );

    final expenses = app.expenseBloc();
    addTearDown(expenses.close);
    final today = DateTime(now.year, now.month, now.day);
    await spend(
      bloc: expenses,
      budgetId: budget.id,
      amount: 3000,
      categoryId: 'food',
      date: today,
    );
    await spend(
      bloc: expenses,
      budgetId: budget.id,
      amount: 1000,
      categoryId: 'food',
      date: today,
    );
    await spend(
      bloc: expenses,
      budgetId: budget.id,
      amount: 2000,
      categoryId: 'fuel',
      date: today,
    );

    final reports = app.reportsBloc();
    addTearDown(reports.close);
    final state = await loadReport(reports, ReportPeriod.thisMonth);
    final data = state.data!;

    expect(data.overview.totalSpending, 6000);
    expect(data.overview.totalTransactions, 3);
    expect(data.overview.highestExpense, 3000);
    expect(data.overview.lowestExpense, 1000);

    // Categories are ranked by spend, with percentages of the total.
    expect(data.categorySlices.first.categoryName, 'Food');
    expect(data.categorySlices.first.amount, 4000);
    expect(data.categorySlices.first.percentage, closeTo(66.67, 0.01));
    final food = data.categoryAnalytics.firstWhere(
      (c) => c.categoryId == 'food',
    );
    expect(food.transactionCount, 2);
    expect(food.averageTransaction, 2000);

    // "This month" is month-to-date: one point per day from the 1st to
    // today, with today carrying the spend.
    expect(data.dailySpending.length, today.day);
    final todayPoint = data.dailySpending.firstWhere(
      (p) =>
          p.date.year == today.year &&
          p.date.month == today.month &&
          p.date.day == today.day,
    );
    expect(todayPoint.amount, 6000);

    // Budget context is attached for the current month.
    expect(data.currentBudget?.id, budget.id);
    expect(data.currentMonthSpent, 6000);
    expect(state.insights, isNotEmpty);
  });

  test('an empty period produces an empty report, not an error', () async {
    await app.addBudget(amount: 10000);
    final reports = app.reportsBloc();
    addTearDown(reports.close);

    final state = await loadReport(reports, ReportPeriod.lastMonth);

    expect(state.status, ReportsStatus.loaded);
    expect(state.errorMessage, isNull);
    expect(state.data!.isEmpty, isTrue);
    expect(state.data!.overview.totalSpending, 0);
  });

  test('deleting an expense updates the next report', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final budget = await app.addBudget(
      amount: 20000,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0),
    );

    final expenses = app.expenseBloc();
    addTearDown(expenses.close);
    final kept = app.newExpense(budgetId: budget.id, amount: 500, date: today);
    final removed = app.newExpense(
      budgetId: budget.id,
      amount: 1500,
      date: today,
    );
    for (final e in [kept, removed]) {
      expenses.add(ExpenseCreate(e));
      await expenses.stream.firstWhere(
        (s) => s.status == ExpenseBlocStatus.success,
      );
    }

    final reports = app.reportsBloc();
    addTearDown(reports.close);
    var state = await loadReport(reports, ReportPeriod.thisMonth);
    expect(state.data!.overview.totalSpending, 2000);

    expenses.add(ExpenseDelete(removed.id));
    await expenses.stream.firstWhere(
      (s) => s.lastAction == ExpenseAction.deleted,
    );

    // The reports BLoC listens to the expense bus and refreshes itself.
    state = await reports.stream.firstWhere(
      (s) =>
          s.status == ReportsStatus.loaded &&
          (s.data?.overview.totalSpending ?? -1) == 500,
    );
    expect(state.data!.overview.totalTransactions, 1);
  });

  test('a category filter narrows the report', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final budget = await app.addBudget(
      amount: 20000,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0),
    );
    final expenses = app.expenseBloc();
    addTearDown(expenses.close);
    await spend(
      bloc: expenses,
      budgetId: budget.id,
      amount: 800,
      categoryId: 'food',
      date: today,
    );
    await spend(
      bloc: expenses,
      budgetId: budget.id,
      amount: 1200,
      categoryId: 'travel',
      date: today,
    );

    final reports = app.reportsBloc();
    addTearDown(reports.close);
    await loadReport(reports, ReportPeriod.thisMonth);

    reports.add(
      const ReportsFilterChanged(ExpenseHistoryFilter(categoryId: 'travel')),
    );
    final filtered = await reports.stream.firstWhere(
      (s) =>
          s.filter.categoryId == 'travel' && s.status == ReportsStatus.loaded,
    );

    expect(filtered.data!.overview.totalSpending, 1200);
    expect(filtered.data!.categorySlices.single.categoryName, 'Travel');
  });
}
