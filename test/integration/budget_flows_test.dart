import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_event.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_state.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/usecases/reset_budget_usecase.dart';

import 'app_harness.dart';

/// Budget-level flows: creating and switching budgets, the safe-spending
/// figure, and starting a new period — all through the real engine.
void main() {
  late AppHarness app;

  setUp(() async => app = await AppHarness.create());
  tearDown(() => app.dispose());

  Future<void> spend(
    ExpenseBloc bloc, {
    required String budgetId,
    required double amount,
    DateTime? date,
  }) async {
    bloc.add(
      ExpenseCreate(
        app.newExpense(budgetId: budgetId, amount: amount, date: date),
      ),
    );
    await bloc.stream.firstWhere(
      (s) =>
          s.status == ExpenseBlocStatus.success ||
          s.status == ExpenseBlocStatus.error,
    );
  }

  test(
    'creating a budget makes it active and visible to the dashboard',
    () async {
      final budget = await app.addBudget(name: 'Trip', amount: 12000);

      expect(app.activeBudgetIdInPreferences, budget.id);

      final dashboard = app.dashboardBloc();
      addTearDown(dashboard.close);
      dashboard.add(const DashboardLoadData());
      final state =
          await dashboard.stream.firstWhere((s) => s is DashboardLoaded)
              as DashboardLoaded;

      expect(state.activeBudgetId, budget.id);
      expect(state.budgetSummary.monthlyAmount, 12000);
      expect(state.budgetSummary.remainingBudget, 12000);
    },
  );

  test(
    'switching budgets re-scopes the dashboard to the other budget',
    () async {
      final first = await app.addBudget(id: 'a', name: 'Daily', amount: 10000);
      final second = await app.addBudget(
        id: 'b',
        name: 'Holiday',
        amount: 50000,
        makeActive: false,
      );

      final expenses = app.expenseBloc();
      addTearDown(expenses.close);
      await spend(expenses, budgetId: first.id, amount: 1000);
      await spend(expenses, budgetId: second.id, amount: 4000);

      var dashboard = app.dashboardBloc();
      dashboard.add(const DashboardLoadData());
      var state =
          await dashboard.stream.firstWhere((s) => s is DashboardLoaded)
              as DashboardLoaded;
      expect(state.budgetSummary.totalSpent, 1000);
      await dashboard.close();

      await app.manageBudget.setActive(second.id);
      expect(app.activeBudgetIdInPreferences, second.id);

      dashboard = app.dashboardBloc();
      addTearDown(dashboard.close);
      dashboard.add(const DashboardLoadData());
      state =
          await dashboard.stream.firstWhere((s) => s is DashboardLoaded)
              as DashboardLoaded;

      expect(state.activeBudgetId, second.id);
      expect(state.budgetSummary.totalSpent, 4000);
      expect(
        state.budgetSummary.remainingBudget,
        46000,
        reason: 'budgets never pool their money',
      );
    },
  );

  test("today's safe spending holds steady as the day is spent", () async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    // A 10-day budget starting today: 10,000 over 10 days.
    final budget = await app.addBudget(
      amount: 10000,
      startDate: start,
      endDate: start.add(const Duration(days: 9)),
    );

    final expenses = app.expenseBloc();
    addTearDown(expenses.close);

    Future<double> safeToday() async {
      final result = await app.getSpendingTargets.callPerBudget();
      return (result as PerBudgetSpendingTargetSuccess)
          .budgetLimits
          .single
          .dailyLimit;
    }

    expect(await safeToday(), 1000);

    await spend(expenses, budgetId: budget.id, amount: 400);
    expect(
      await safeToday(),
      1000,
      reason: "spending today counts against today's limit, not into it",
    );

    final afterSpending = await app.getSpendingTargets.callPerBudget();
    final limit =
        (afterSpending as PerBudgetSpendingTargetSuccess).budgetLimits.single;
    expect(limit.spentToday, 400);
    expect(limit.remainingToday, 600);
    expect(limit.isOverLimit, isFalse);

    // Overspending today is reported, and the limit still does not move.
    await spend(expenses, budgetId: budget.id, amount: 900);
    final over =
        (await app.getSpendingTargets.callPerBudget()
                as PerBudgetSpendingTargetSuccess)
            .budgetLimits
            .single;
    expect(over.dailyLimit, 1000);
    expect(over.spentToday, 1300);
    expect(over.exceededToday, 300);
    expect(over.isOverLimit, isTrue);
  });

  test('yesterday’s spending lowers today’s safe amount', () async {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
    // 10-day budget that began yesterday; 9 days remain including today.
    final budget = await app.addBudget(
      amount: 10000,
      startDate: start,
      endDate: start.add(const Duration(days: 9)),
    );

    final expenses = app.expenseBloc();
    addTearDown(expenses.close);
    await spend(expenses, budgetId: budget.id, amount: 1000, date: start);

    final result =
        await app.getSpendingTargets.callPerBudget()
            as PerBudgetSpendingTargetSuccess;
    final limit = result.budgetLimits.single;

    expect(limit.spentToday, 0);
    expect(limit.remainingDays, 9);
    expect(limit.dailyLimit, closeTo(1000, 0.001), reason: '9,000 ÷ 9 days');
  });

  test(
    'a budget whose period has not started reports no daily limit',
    () async {
      final today = DateTime.now();
      final start = DateTime(
        today.year,
        today.month,
        today.day,
      ).add(const Duration(days: 5));
      await app.addBudget(amount: 5000, startDate: start);

      final result = await app.getSpendingTargets.callPerBudget();
      expect(result, isA<PerBudgetSpendingTargetNoBudget>());
    },
  );

  test(
    'deleting a budget removes its expenses and leaves others alone',
    () async {
      final keep = await app.addBudget(id: 'keep', amount: 5000);
      final drop = await app.addBudget(
        id: 'drop',
        amount: 5000,
        makeActive: false,
      );
      final expenses = app.expenseBloc();
      addTearDown(expenses.close);
      await spend(expenses, budgetId: keep.id, amount: 100);
      await spend(expenses, budgetId: drop.id, amount: 200);

      await app.manageBudget.delete(drop.id);

      expect(await app.budgetRepository.getBudgetById(drop.id), isNull);
      expect(
        (await app.expenseRepository.getExpenses(budgetId: drop.id)),
        isEmpty,
      );
      expect(
        (await app.expenseRepository.getExpenses(
          budgetId: keep.id,
        )).single.amount,
        100,
      );
      expect(await app.storedRemaining(keep.id), 4900);
    },
  );

  test(
    'starting a new period archives the old budget and carries it over',
    () async {
      final original = await app.addBudget(
        name: 'Monthly',
        amount: 20000,
        currency: 'USD',
      );
      final expenses = app.expenseBloc();
      addTearDown(expenses.close);
      await spend(expenses, budgetId: original.id, amount: 3000);

      final reset = ResetBudgetUseCase(repository: app.budgetRepository);
      final result = await reset.resetCurrentMonth();
      final newId = (result as SettingsSuccess<String>).data;

      final budgets = await app.allBudgets();
      expect(budgets.length, 2, reason: 'exactly one new budget');
      expect(budgets.firstWhere((b) => b.id == original.id).isArchived, isTrue);

      final fresh = budgets.firstWhere((b) => b.id == newId);
      expect(fresh.name, 'Monthly');
      expect(fresh.monthlyAmount, 20000);
      expect(fresh.currency, 'USD');
      expect(fresh.remainingAmount, 20000, reason: 'a clean slate');
      expect(app.activeBudgetIdInPreferences, newId);

      // The old expenses stay with the archived budget.
      expect(
        (await app.expenseRepository.getExpenses(
          budgetId: original.id,
        )).single.amount,
        3000,
      );
    },
  );

  test(
    'changing the budget amount keeps expenses and re-derives remaining',
    () async {
      final budget = await app.addBudget(amount: 10000);
      final expenses = app.expenseBloc();
      addTearDown(expenses.close);
      await spend(expenses, budgetId: budget.id, amount: 2500);
      expect(await app.storedRemaining(budget.id), 7500);

      final reset = ResetBudgetUseCase(repository: app.budgetRepository);
      await reset.resetBudgetAmount(20000);

      expect(await app.storedRemaining(budget.id), 17500);
      final summary = await app.getBudgetSummary(budgetId: budget.id);
      final data = (summary as BudgetSuccess<BudgetSummaryEntity>).data;
      expect(data.totalSpent, 2500);
      expect(data.monthlyAmount, 20000);
    },
  );
}
