import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/data/datasource/bill_local_datasource_impl.dart';
import 'package:monivo/features/bills/data/repository/bill_repository_impl.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_summary_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/dashboard/data/datasource/dashboard_local_datasource_impl.dart';
import 'package:monivo/features/dashboard/data/repository/dashboard_repository_impl.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_recent_expenses_usecase.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_smart_insights_usecase.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/in_memory_database.dart';

/// Verifies that the Dashboard rebuilds with the updated budget amount after
/// a budget is edited through the normal ManageBudgetUseCase → repository
/// flow followed by the existing RefreshBuses.budgets notification — the exact
/// sequence BudgetFormScreen performs on save.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late BudgetRepositoryImpl budgetRepository;
  late ExpenseRepositoryImpl expenseRepository;
  late ManageBudgetUseCase manageBudget;
  late DashboardBloc bloc;

  late DateTime today;
  late DateTime periodStart;
  late DateTime periodEnd;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    database = await createInMemoryDatabase();
    final calculationService = BudgetCalculationService();

    budgetRepository = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(
        database: database,
        sharedPreferences: prefs,
      ),
      calculationService: calculationService,
    );
    final expenseDataSource = ExpenseLocalDataSourceImpl(database: database);
    await expenseDataSource.seedDefaultCategories(defaultCategories);
    expenseRepository = ExpenseRepositoryImpl(
      localDataSource: expenseDataSource,
      budgetRepository: budgetRepository,
    );
    manageBudget = ManageBudgetUseCase(repository: budgetRepository);

    bloc = DashboardBloc(
      getBudgetSummaryUseCase: GetBudgetSummaryUseCase(
        repository: budgetRepository,
        calculationService: calculationService,
      ),
      getRecentExpensesUseCase: GetRecentExpensesUseCase(
        repository: DashboardRepositoryImpl(
          localDataSource: DashboardLocalDataSourceImpl(database: database),
        ),
      ),
      getSmartInsightsUseCase: const GetSmartInsightsUseCase(),
      getSpendingTargetsUseCase: GetSpendingTargetsUseCase(
        repository: budgetRepository,
        calculationService: calculationService,
      ),
      budgetRepository: budgetRepository,
      billRepository: BillRepositoryImpl(
        localDataSource: BillLocalDataSourceImpl(database: database),
      ),
    );

    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    periodStart = today.subtract(const Duration(days: 9));
    periodEnd = today.add(const Duration(days: 20));
  });

  tearDown(() async {
    await bloc.close();
    await database.close();
  });

  BudgetEntity budget(String id, double amount) {
    return BudgetEntity(
      id: id,
      name: 'Budget $id',
      monthlyAmount: amount,
      remainingAmount: amount,
      currency: 'INR',
      startDate: periodStart,
      endDate: periodEnd,
      createdAt: periodStart,
      updatedAt: periodStart,
    );
  }

  Future<void> addExpense(String budgetId, double amount) async {
    await expenseRepository.createExpense(
      ExpenseEntity(
        id: 'exp_${budgetId}_${DateTime.now().microsecondsSinceEpoch}',
        budgetId: budgetId,
        amount: amount,
        categoryId: defaultCategories.first.id,
        date: today,
        time: today,
        createdAt: today,
        updatedAt: today,
      ),
    );
  }

  /// Same steps as BudgetFormScreen._save for an existing budget.
  Future<void> editAmountLikeTheForm(String budgetId, double newAmount) async {
    final loaded = await manageBudget.getById(budgetId);
    await manageBudget.update(
      loaded!.copyWith(monthlyAmount: newAmount, updatedAt: DateTime.now()),
    );
    RefreshBuses.budgets.notifyChanged();
  }

  Future<DashboardLoaded> nextLoaded() {
    return bloc.stream
        .where((s) => s is DashboardLoaded)
        .cast<DashboardLoaded>()
        .first
        .timeout(const Duration(seconds: 5));
  }

  test('active budget edit updates every dashboard section', () async {
    await manageBudget.create(budget('a', 10000));
    await manageBudget.create(budget('b', 20000));
    await manageBudget.setActive('a');
    await addExpense('a', 3000);
    await addExpense('b', 5000);

    final initial = nextLoaded();
    bloc.add(const DashboardLoadData());
    final before = await initial;
    expect(before.budgetSummary.monthlyAmount, 10000);
    expect(before.budgetSummary.remainingBudget, 7000);

    final refreshed = nextLoaded();
    await editAmountLikeTheForm('a', 15000);
    final after = await refreshed;

    // Main budget card.
    expect(after.budgetSummary.monthlyAmount, 15000);
    expect(after.budgetSummary.remainingBudget, 12000);
    expect(after.budgetSummary.budgetUtilization, closeTo(3000 / 15000, 1e-9));

    // Today's Safe Spending section (per-budget limits).
    final limitA = after.budgetDailyLimits.singleWhere(
      (l) => l.budgetId == 'a',
    );
    expect(limitA.monthlyAmount, 15000);
    expect(limitA.remainingBudget, 12000);
    expect(
      limitA.dailyLimit,
      closeTo(after.budgetSummary.dailySafeSpending, 1e-9),
    );

    // Spending target derived for the active budget.
    expect(after.spendingTarget, isNotNull);
    expect(after.spendingTarget!.dailyTarget, closeTo(limitA.dailyLimit, 1e-9));

    // Smart insights are regenerated from the new summary (never empty).
    expect(after.insights, isNotEmpty);

    // Other budget unchanged.
    final limitB = after.budgetDailyLimits.singleWhere(
      (l) => l.budgetId == 'b',
    );
    expect(limitB.monthlyAmount, 20000);
    expect(limitB.remainingBudget, 15000);
  });

  test(
    'non-active budget edit leaves the active budget summary unchanged',
    () async {
      await manageBudget.create(budget('a', 10000));
      await manageBudget.create(budget('b', 20000));
      await manageBudget.setActive('a');
      await addExpense('a', 3000);
      await addExpense('b', 5000);

      final initial = nextLoaded();
      bloc.add(const DashboardLoadData());
      final before = await initial;

      final refreshed = nextLoaded();
      await editAmountLikeTheForm('b', 8000);
      final after = await refreshed;

      // Active budget (a) is exactly as before.
      expect(after.budgetSummary, equals(before.budgetSummary));
      final limitA = after.budgetDailyLimits.singleWhere(
        (l) => l.budgetId == 'a',
      );
      final limitABefore = before.budgetDailyLimits.singleWhere(
        (l) => l.budgetId == 'a',
      );
      expect(limitA, equals(limitABefore));

      // Edited budget (b) reflects its new amount in its own entry.
      final limitB = after.budgetDailyLimits.singleWhere(
        (l) => l.budgetId == 'b',
      );
      expect(limitB.monthlyAmount, 8000);
      expect(limitB.remainingBudget, 3000);

      // Switching to b afterwards shows the updated values immediately.
      final switched = nextLoaded();
      await manageBudget.setActive('b');
      RefreshBuses.budgets.notifyChanged();
      final afterSwitch = await switched;
      expect(afterSwitch.budgetSummary.monthlyAmount, 8000);
      expect(afterSwitch.budgetSummary.remainingBudget, 3000);
    },
  );
}
