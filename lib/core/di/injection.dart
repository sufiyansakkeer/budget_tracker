import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../../features/budget/data/datasource/budget_local_datasource.dart';
import '../../features/budget/data/datasource/budget_local_datasource_impl.dart';
import '../../features/budget/data/repository/budget_repository_impl.dart';
import '../../features/budget/domain/repository/budget_repository.dart';
import '../../features/budget/domain/services/budget_calculation_service.dart';
import '../../features/budget/domain/usecases/calculate_daily_allowance_usecase.dart';
import '../../features/budget/domain/usecases/get_budget_analytics_usecase.dart';
import '../../features/budget/domain/usecases/get_budget_status_usecase.dart';
import '../../features/budget/domain/usecases/get_budget_summary_usecase.dart';
import '../../features/budget/domain/usecases/get_projected_overspending_usecase.dart';
import '../../features/budget/domain/usecases/get_projected_savings_usecase.dart';
import '../../features/budget/presentation/bloc/budget_bloc.dart';
import '../../features/dashboard/data/datasource/dashboard_local_datasource.dart';
import '../../features/dashboard/data/datasource/dashboard_local_datasource_impl.dart';
import '../../features/dashboard/data/repository/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repository/dashboard_repository.dart';
import '../../features/dashboard/domain/usecases/get_recent_expenses_usecase.dart';
import '../../features/dashboard/domain/usecases/get_smart_insights_usecase.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/expenses/data/datasource/expense_local_datasource.dart';
import '../../features/expenses/data/datasource/expense_local_datasource_impl.dart';
import '../../features/expenses/data/repository/expense_repository_impl.dart';
import '../../features/expenses/domain/repository/expense_repository.dart';
import '../../features/expenses/domain/usecases/create_expense_usecase.dart';
import '../../features/expenses/domain/usecases/delete_expense_usecase.dart';
import '../../features/expenses/domain/usecases/get_categories_usecase.dart';
import '../../features/expenses/domain/usecases/get_expense_by_id_usecase.dart';
import '../../features/expenses/domain/usecases/get_expenses_usecase.dart';
import '../../features/expenses/domain/usecases/update_expense_usecase.dart';
import '../../features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import '../../features/expenses/domain/usecases/filter_expenses_usecase.dart';
import '../../features/expenses/domain/usecases/group_expenses_usecase.dart';
import '../../features/expenses/domain/usecases/page_expenses_usecase.dart';
import '../../features/expenses/domain/usecases/search_expenses_usecase.dart';
import '../../features/expenses/domain/usecases/sort_expenses_usecase.dart';
import '../../features/expenses/presentation/bloc/expense_bloc.dart';
import '../../features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import '../../features/onboarding/data/datasource/onboarding_local_datasource.dart';
import '../../features/onboarding/data/repository/onboarding_repository_impl.dart';
import '../../features/onboarding/domain/repository/onboarding_repository.dart';
import '../../features/onboarding/domain/usecases/check_first_launch_usecase.dart';
import '../../features/onboarding/domain/usecases/create_budget_usecase.dart';
import '../../features/onboarding/presentation/bloc/onboarding_bloc.dart';
import '../../features/reports/data/repository/reports_repository_impl.dart';
import '../../features/reports/domain/repository/reports_repository.dart';
import '../../features/reports/domain/services/analytics_service.dart';
import '../../features/reports/domain/services/report_insight_generator.dart';
import '../../features/reports/domain/usecases/get_report_data_usecase.dart';
import '../../features/reports/presentation/bloc/reports_bloc.dart';

final GetIt getIt = GetIt.instance;

Future<void> initDependencyInjection() async {
  // 1. SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // 2. Local Database
  final database = AppDatabase();
  getIt.registerSingleton<AppDatabase>(database);

  // 3. Budget Engine - Core Service
  getIt.registerLazySingleton<BudgetCalculationService>(
    () => BudgetCalculationService(),
  );

  // 4. Onboarding Feature - Datasources
  getIt.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(
      sharedPreferences: getIt<SharedPreferences>(),
      database: getIt<AppDatabase>(),
    ),
  );

  // 5. Budget Feature - Datasources
  getIt.registerLazySingleton<BudgetLocalDataSource>(
    () => BudgetLocalDataSourceImpl(database: getIt<AppDatabase>()),
  );

  // 6. Onboarding Feature - Repositories
  getIt.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(
      localDataSource: getIt<OnboardingLocalDataSource>(),
    ),
  );

  // 7. Budget Feature - Repositories
  getIt.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(
      localDataSource: getIt<BudgetLocalDataSource>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  // 8. Onboarding Feature - Use Cases
  getIt.registerLazySingleton<CheckFirstLaunchUseCase>(
    () => CheckFirstLaunchUseCase(getIt<OnboardingRepository>()),
  );

  getIt.registerLazySingleton<CreateBudgetUseCase>(
    () => CreateBudgetUseCase(getIt<OnboardingRepository>()),
  );

  // 9. Budget Feature - Use Cases
  getIt.registerLazySingleton<GetBudgetSummaryUseCase>(
    () => GetBudgetSummaryUseCase(
      repository: getIt<BudgetRepository>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  getIt.registerLazySingleton<CalculateDailyAllowanceUseCase>(
    () => CalculateDailyAllowanceUseCase(
      repository: getIt<BudgetRepository>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  getIt.registerLazySingleton<GetBudgetAnalyticsUseCase>(
    () => GetBudgetAnalyticsUseCase(
      repository: getIt<BudgetRepository>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  getIt.registerLazySingleton<GetBudgetStatusUseCase>(
    () => GetBudgetStatusUseCase(
      repository: getIt<BudgetRepository>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  getIt.registerLazySingleton<GetProjectedSavingsUseCase>(
    () => GetProjectedSavingsUseCase(
      repository: getIt<BudgetRepository>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  getIt.registerLazySingleton<GetProjectedOverspendingUseCase>(
    () => GetProjectedOverspendingUseCase(
      repository: getIt<BudgetRepository>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  // 10. Onboarding Feature - BLoC
  getIt.registerFactory<OnboardingBloc>(
    () => OnboardingBloc(createBudgetUseCase: getIt<CreateBudgetUseCase>()),
  );

  // 11. Budget Feature - BLoC
  getIt.registerFactory<BudgetBloc>(
    () => BudgetBloc(
      getBudgetSummaryUseCase: getIt<GetBudgetSummaryUseCase>(),
      getBudgetAnalyticsUseCase: getIt<GetBudgetAnalyticsUseCase>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  // 12. Dashboard Feature - Datasources
  getIt.registerLazySingleton<DashboardLocalDataSource>(
    () => DashboardLocalDataSourceImpl(database: getIt<AppDatabase>()),
  );

  // 13. Dashboard Feature - Repositories
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(
      localDataSource: getIt<DashboardLocalDataSource>(),
    ),
  );

  // 14. Dashboard Feature - Use Cases
  getIt.registerLazySingleton<GetRecentExpensesUseCase>(
    () => GetRecentExpensesUseCase(repository: getIt<DashboardRepository>()),
  );

  getIt.registerLazySingleton<GetSmartInsightsUseCase>(
    () => const GetSmartInsightsUseCase(),
  );

  // 15. Dashboard Feature - BLoC
  getIt.registerFactory<DashboardBloc>(
    () => DashboardBloc(
      getBudgetSummaryUseCase: getIt<GetBudgetSummaryUseCase>(),
      getRecentExpensesUseCase: getIt<GetRecentExpensesUseCase>(),
      getSmartInsightsUseCase: getIt<GetSmartInsightsUseCase>(),
    ),
  );

  // 16. Expense Feature - Datasources
  getIt.registerLazySingleton<ExpenseLocalDataSource>(
    () => ExpenseLocalDataSourceImpl(database: getIt<AppDatabase>()),
  );

  // 17. Expense Feature - Repositories
  getIt.registerLazySingleton<ExpenseRepository>(
    () =>
        ExpenseRepositoryImpl(localDataSource: getIt<ExpenseLocalDataSource>()),
  );

  // 18. Expense Feature - Use Cases
  getIt.registerLazySingleton<CreateExpenseUseCase>(
    () => CreateExpenseUseCase(repository: getIt<ExpenseRepository>()),
  );
  getIt.registerLazySingleton<UpdateExpenseUseCase>(
    () => UpdateExpenseUseCase(repository: getIt<ExpenseRepository>()),
  );
  getIt.registerLazySingleton<DeleteExpenseUseCase>(
    () => DeleteExpenseUseCase(repository: getIt<ExpenseRepository>()),
  );
  getIt.registerLazySingleton<GetExpenseByIdUseCase>(
    () => GetExpenseByIdUseCase(repository: getIt<ExpenseRepository>()),
  );
  getIt.registerLazySingleton<GetExpensesUseCase>(
    () => GetExpensesUseCase(repository: getIt<ExpenseRepository>()),
  );
  getIt.registerLazySingleton<GetCategoriesUseCase>(
    () => GetCategoriesUseCase(repository: getIt<ExpenseRepository>()),
  );

  // 19. Expense Feature - BLoC
  getIt.registerFactory<ExpenseBloc>(
    () => ExpenseBloc(
      createExpenseUseCase: getIt<CreateExpenseUseCase>(),
      updateExpenseUseCase: getIt<UpdateExpenseUseCase>(),
      deleteExpenseUseCase: getIt<DeleteExpenseUseCase>(),
      getExpenseByIdUseCase: getIt<GetExpenseByIdUseCase>(),
      getExpensesUseCase: getIt<GetExpensesUseCase>(),
      getCategoriesUseCase: getIt<GetCategoriesUseCase>(),
      repository: getIt<ExpenseRepository>(),
    ),
  );

  // 20. Expense History - Pure use cases
  getIt.registerLazySingleton<SearchExpensesUseCase>(
    () => const SearchExpensesUseCase(),
  );
  getIt.registerLazySingleton<FilterExpensesUseCase>(
    () => const FilterExpensesUseCase(),
  );
  getIt.registerLazySingleton<SortExpensesUseCase>(
    () => const SortExpensesUseCase(),
  );
  getIt.registerLazySingleton<CalculateExpenseSummaryUseCase>(
    () => const CalculateExpenseSummaryUseCase(),
  );
  getIt.registerLazySingleton<GroupExpensesUseCase>(
    () => const GroupExpensesUseCase(),
  );
  getIt.registerLazySingleton<PageExpensesUseCase>(
    () => const PageExpensesUseCase(),
  );

  // 21. Expense History - BLoC
  getIt.registerFactory<ExpenseHistoryBloc>(
    () => ExpenseHistoryBloc(
      getExpensesUseCase: getIt<GetExpensesUseCase>(),
      getCategoriesUseCase: getIt<GetCategoriesUseCase>(),
      searchExpensesUseCase: getIt<SearchExpensesUseCase>(),
      filterExpensesUseCase: getIt<FilterExpensesUseCase>(),
      sortExpensesUseCase: getIt<SortExpensesUseCase>(),
      calculateExpenseSummaryUseCase: getIt<CalculateExpenseSummaryUseCase>(),
      pageExpensesUseCase: getIt<PageExpensesUseCase>(),
    ),
  );

  // 22. Reports Feature - Repository
  getIt.registerLazySingleton<ReportsRepository>(
    () => ReportsRepositoryImpl(
      getExpensesUseCase: getIt<GetExpensesUseCase>(),
      getCategoriesUseCase: getIt<GetCategoriesUseCase>(),
      filterExpensesUseCase: getIt<FilterExpensesUseCase>(),
      budgetRepository: getIt<BudgetRepository>(),
    ),
  );

  // 23. Reports Feature - Services
  getIt.registerLazySingleton<AnalyticsService>(() => const AnalyticsService());
  getIt.registerLazySingleton<ReportInsightGenerator>(
    () => const ReportInsightGenerator(),
  );

  // 24. Reports Feature - Use Case
  getIt.registerLazySingleton<GetReportDataUseCase>(
    () => GetReportDataUseCase(
      repository: getIt<ReportsRepository>(),
      analyticsService: getIt<AnalyticsService>(),
    ),
  );

  // 25. Reports Feature - BLoC
  getIt.registerFactory<ReportsBloc>(
    () => ReportsBloc(
      getReportDataUseCase: getIt<GetReportDataUseCase>(),
      insightGenerator: getIt<ReportInsightGenerator>(),
    ),
  );
}
