import 'package:monivo/core/constants/preference_keys.dart';
import 'package:monivo/core/data/models/budget_model.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/data/datasource/bill_local_datasource_impl.dart';
import 'package:monivo/features/bills/data/repository/bill_repository_impl.dart';
import 'package:monivo/features/bills/domain/repository/bill_repository.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_summary_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/dashboard/data/datasource/dashboard_local_datasource_impl.dart';
import 'package:monivo/features/dashboard/data/repository/dashboard_repository_impl.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_recent_expenses_usecase.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_smart_insights_usecase.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/repository/expense_repository.dart';
import 'package:monivo/features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/create_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/delete_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expense_by_id_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_for_budgets_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/page_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/search_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/sort_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/update_expense_usecase.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:monivo/features/reports/data/repository/reports_repository_impl.dart';
import 'package:monivo/features/reports/domain/services/analytics_service.dart';
import 'package:monivo/features/reports/domain/services/report_insight_generator.dart';
import 'package:monivo/features/reports/domain/usecases/get_report_data_usecase.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../helpers/in_memory_database.dart';

/// Wires the real datasources, repositories, use cases and BLoCs against an
/// in-memory database — the same object graph `initDependencyInjection`
/// builds, minus anything that needs a device.
///
/// Tests built on this exercise a whole flow end to end: a BLoC event goes
/// through its use case and repository into SQLite, and the resulting state
/// is read back through other features' BLoCs. Only platform services
/// (notifications, biometrics, widgets, file pickers) are left out.
class AppHarness {
  final AppDatabase database;
  final SharedPreferences preferences;

  final BudgetRepository budgetRepository;
  final ExpenseRepository expenseRepository;
  final BillRepository billRepository;

  final BudgetCalculationService calculationService;
  final ManageBudgetUseCase manageBudget;
  final GetBudgetSummaryUseCase getBudgetSummary;
  final GetSpendingTargetsUseCase getSpendingTargets;

  AppHarness._({
    required this.database,
    required this.preferences,
    required this.budgetRepository,
    required this.expenseRepository,
    required this.billRepository,
    required this.calculationService,
    required this.manageBudget,
    required this.getBudgetSummary,
    required this.getSpendingTargets,
  });

  static Future<AppHarness> create() async {
    final database = await createInMemoryDatabase();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final calculationService = BudgetCalculationService();
    final budgetRepository = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(
        database: database,
        sharedPreferences: preferences,
      ),
      calculationService: calculationService,
    );
    final expenseRepository = ExpenseRepositoryImpl(
      localDataSource: ExpenseLocalDataSourceImpl(database: database),
      budgetRepository: budgetRepository,
    );
    final billRepository = BillRepositoryImpl(
      localDataSource: BillLocalDataSourceImpl(database: database),
    );

    return AppHarness._(
      database: database,
      preferences: preferences,
      budgetRepository: budgetRepository,
      expenseRepository: expenseRepository,
      billRepository: billRepository,
      calculationService: calculationService,
      manageBudget: ManageBudgetUseCase(repository: budgetRepository),
      getBudgetSummary: GetBudgetSummaryUseCase(
        repository: budgetRepository,
        calculationService: calculationService,
      ),
      getSpendingTargets: GetSpendingTargetsUseCase(
        repository: budgetRepository,
        calculationService: calculationService,
      ),
    );
  }

  Future<void> dispose() => database.close();

  // ── BLoCs (new instance per call, like the DI factories) ────────────────

  ExpenseBloc expenseBloc() => ExpenseBloc(
    createExpenseUseCase: CreateExpenseUseCase(repository: expenseRepository),
    updateExpenseUseCase: UpdateExpenseUseCase(repository: expenseRepository),
    deleteExpenseUseCase: DeleteExpenseUseCase(repository: expenseRepository),
    getExpenseByIdUseCase: GetExpenseByIdUseCase(repository: expenseRepository),
    getExpensesUseCase: GetExpensesUseCase(repository: expenseRepository),
    getCategoriesUseCase: GetCategoriesUseCase(repository: expenseRepository),
    repository: expenseRepository,
    budgetRepository: budgetRepository,
  );

  ExpenseHistoryBloc historyBloc() => ExpenseHistoryBloc(
    getExpensesUseCase: GetExpensesUseCase(repository: expenseRepository),
    getExpensesForBudgetsUseCase: GetExpensesForBudgetsUseCase(
      repository: expenseRepository,
    ),
    getCategoriesUseCase: GetCategoriesUseCase(repository: expenseRepository),
    searchExpensesUseCase: const SearchExpensesUseCase(),
    filterExpensesUseCase: const FilterExpensesUseCase(),
    sortExpensesUseCase: const SortExpensesUseCase(),
    calculateExpenseSummaryUseCase: const CalculateExpenseSummaryUseCase(),
    pageExpensesUseCase: const PageExpensesUseCase(),
    budgetRepository: budgetRepository,
  );

  DashboardBloc dashboardBloc() => DashboardBloc(
    getBudgetSummaryUseCase: getBudgetSummary,
    getRecentExpensesUseCase: GetRecentExpensesUseCase(
      repository: DashboardRepositoryImpl(
        localDataSource: DashboardLocalDataSourceImpl(database: database),
      ),
    ),
    getSmartInsightsUseCase: const GetSmartInsightsUseCase(),
    getSpendingTargetsUseCase: getSpendingTargets,
    budgetRepository: budgetRepository,
    billRepository: billRepository,
  );

  ReportsBloc reportsBloc() => ReportsBloc(
    getReportDataUseCase: GetReportDataUseCase(
      repository: ReportsRepositoryImpl(
        getExpensesUseCase: GetExpensesUseCase(repository: expenseRepository),
        getCategoriesUseCase: GetCategoriesUseCase(
          repository: expenseRepository,
        ),
        filterExpensesUseCase: const FilterExpensesUseCase(),
        budgetRepository: budgetRepository,
      ),
      analyticsService: const AnalyticsService(),
    ),
    insightGenerator: const ReportInsightGenerator(),
  );

  // ── Fixtures ────────────────────────────────────────────────────────────

  /// Creates a budget and (by default) makes it the active one.
  Future<BudgetEntity> addBudget({
    String? id,
    String name = 'Personal',
    double amount = 30000,
    String currency = 'INR',
    DateTime? startDate,
    DateTime? endDate,
    bool makeActive = true,
  }) async {
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, now.day);
    final budget = BudgetEntity(
      id: id ?? const Uuid().v4(),
      name: name,
      monthlyAmount: amount,
      remainingAmount: amount,
      currency: currency,
      startDate: start,
      endDate: endDate ?? start.add(const Duration(days: 29)),
      createdAt: now,
      updatedAt: now,
    );
    await budgetRepository.createBudget(budget);
    if (makeActive) await budgetRepository.setActiveBudgetId(budget.id);
    return budget;
  }

  /// Builds an expense entity; pass it to an [ExpenseBloc] to persist it.
  ExpenseEntity newExpense({
    String? id,
    required String budgetId,
    required double amount,
    String categoryId = 'food',
    String? note,
    DateTime? date,
    List<String> tags = const [],
  }) {
    final now = DateTime.now();
    final when = date ?? DateTime(now.year, now.month, now.day);
    return ExpenseEntity(
      id: id ?? const Uuid().v4(),
      budgetId: budgetId,
      amount: amount,
      categoryId: categoryId,
      note: note,
      date: when,
      time: when.add(const Duration(hours: 12)),
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// The stored remaining amount, read straight from the database.
  Future<double> storedRemaining(String budgetId) async {
    final budget = await budgetRepository.getBudgetById(budgetId);
    return budget!.remainingAmount;
  }

  /// The id the app considers active, read straight from preferences.
  String? get activeBudgetIdInPreferences =>
      preferences.getString(PreferenceKeys.activeBudgetId);

  /// Every stored budget row, oldest start date first.
  Future<List<BudgetEntity>> allBudgets() async {
    final rows = await database.select(database.budgets).get();
    final list = rows.map(BudgetModel.toEntity).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return list;
  }
}
