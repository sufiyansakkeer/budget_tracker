import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/services/database_integrity_service.dart';
import '../../features/settings/data/datasource/settings_local_datasource.dart';
import '../../features/settings/data/datasource/settings_local_datasource_impl.dart';
import '../../features/settings/data/repository/settings_repository_impl.dart';
import '../../features/settings/domain/repository/settings_repository.dart';
import '../../features/settings/domain/services/backup_service.dart';
import '../../features/settings/domain/services/biometric_service.dart';
import '../../features/settings/domain/services/export_service.dart';
import '../../features/settings/domain/services/import_service.dart';
import '../../features/settings/domain/services/notification_service.dart';
import '../../features/settings/domain/usecases/backup_data_usecase.dart';
import '../../features/settings/domain/usecases/export_data_usecase.dart';
import '../../features/settings/domain/usecases/import_data_usecase.dart';
import '../../features/settings/domain/usecases/load_settings_usecase.dart';
import '../../features/settings/domain/usecases/reset_budget_usecase.dart';
import '../../features/settings/domain/usecases/restore_data_usecase.dart';
import '../../features/settings/domain/usecases/schedule_notifications_usecase.dart';
import '../../features/settings/domain/usecases/update_biometric_usecase.dart';
import '../../features/settings/domain/usecases/update_currency_usecase.dart';
import '../../features/settings/domain/usecases/update_notification_settings_usecase.dart';
import '../../features/settings/domain/repository/theme_repository.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../features/settings/presentation/bloc/theme/theme_event.dart';
import '../../features/settings/presentation/bloc/theme/theme_bloc.dart';
import '../database/app_database.dart';
import '../currency/currency_provider.dart';
import '../notifications/notification_bloc.dart';
import '../biometric/biometric_initializer.dart';
import '../biometric/app_lock_bloc.dart';
import '../biometric/app_lock_event.dart';
import '../../features/budget/data/datasource/budget_local_datasource.dart';
import '../../features/budget/data/datasource/budget_local_datasource_impl.dart';
import '../../features/budget/data/repository/budget_repository_impl.dart';
import '../../features/budget/domain/repository/budget_repository.dart';
import '../../features/budget/domain/services/budget_calculation_service.dart';
import '../../features/budget/domain/services/safe_to_spend_calculator.dart';
import '../../features/budget/domain/usecases/get_budget_list_summary_usecase.dart';
import '../../features/budget/domain/usecases/recalculate_remaining_amounts_usecase.dart';
import '../../features/budget/domain/usecases/get_budget_summary_usecase.dart';
import '../../features/budget/domain/usecases/manage_budget_usecase.dart';
import '../../features/dashboard/data/datasource/dashboard_local_datasource.dart';
import '../../features/dashboard/data/datasource/dashboard_local_datasource_impl.dart';
import '../../features/dashboard/data/repository/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repository/dashboard_repository.dart';
import '../../features/dashboard/domain/services/bill_occurrence_enumerator.dart';
import '../../features/categories/data/datasource/category_local_datasource.dart';
import '../../features/categories/data/datasource/category_local_datasource_impl.dart';
import '../../features/categories/data/repository/category_repository_impl.dart';
import '../../features/categories/domain/repository/category_repository.dart';
import '../../features/categories/domain/usecases/archive_category_usecase.dart';
import '../../features/categories/domain/usecases/delete_category_usecase.dart';
import '../../features/categories/domain/usecases/load_categories_usecase.dart';
import '../../features/categories/domain/usecases/save_category_usecase.dart';
import '../../features/categories/presentation/bloc/category_bloc.dart';
import '../../features/dashboard/domain/usecases/get_recent_expenses_usecase.dart';
import '../../features/dashboard/domain/usecases/get_linkable_bills_usecase.dart';
import '../../features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart';
import '../../features/dashboard/domain/usecases/get_spending_pace_usecase.dart';
import '../../features/dashboard/domain/usecases/get_smart_insights_usecase.dart';
import '../../features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/expenses/data/datasource/expense_local_datasource.dart';
import '../../features/expenses/data/datasource/expense_local_datasource_impl.dart';
import '../../features/expenses/data/repository/expense_repository_impl.dart';
import '../../features/expenses/domain/repository/expense_repository.dart';
import '../../features/expenses/domain/usecases/create_expense_usecase.dart';
import '../../features/expenses/domain/usecases/delete_expense_usecase.dart';
import '../../features/expenses/domain/usecases/get_categories_usecase.dart';
import '../../features/expenses/domain/usecases/get_expense_by_id_usecase.dart';
import '../../features/expenses/domain/usecases/get_expenses_for_budgets_usecase.dart';
import '../../features/expenses/domain/usecases/get_expenses_usecase.dart';
import '../../features/expenses/domain/usecases/update_expense_usecase.dart';
import '../../features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import '../../features/expenses/domain/usecases/filter_expenses_usecase.dart';
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
import '../../features/bills/data/datasource/bill_local_datasource.dart';
import '../../features/bills/data/datasource/bill_local_datasource_impl.dart';
import '../../features/bills/data/repository/bill_repository_impl.dart';
import '../../features/bills/domain/repository/bill_repository.dart';
import '../../features/bills/domain/usecases/create_bill_usecase.dart';
import '../../features/bills/domain/usecases/delete_bill_usecase.dart';
import '../../features/bills/domain/usecases/get_bill_by_id_usecase.dart';
import '../../features/bills/domain/usecases/get_bills_usecase.dart';
import '../../features/bills/domain/usecases/link_bills_to_budget_usecase.dart';
import '../../features/bills/domain/usecases/mark_bill_paid_usecase.dart';
import '../../features/bills/domain/usecases/mark_bill_unpaid_usecase.dart';
import '../../features/bills/domain/usecases/pay_bill_usecase.dart';
import '../../features/bills/domain/usecases/schedule_bill_reminder_usecase.dart';
import '../../features/bills/domain/usecases/update_bill_usecase.dart';
import '../../features/bills/presentation/bloc/bill_bloc.dart';
import '../../features/app_update/data/datasources/github_release_remote_datasource.dart';
import '../../features/app_update/data/datasources/github_release_remote_datasource_impl.dart';
import '../../features/app_update/data/repository/app_update_repository_impl.dart';
import '../../features/app_update/domain/repository/app_update_repository.dart';
import '../../features/app_update/domain/usecases/check_for_app_update_usecase.dart';
import '../../features/app_update/presentation/bloc/app_update_bloc.dart';
import '../../features/currency_converter/data/datasources/currency_local_datasource.dart';
import '../../features/currency_converter/data/datasources/currency_local_datasource_impl.dart';
import '../../features/currency_converter/data/datasources/currency_remote_datasource.dart';
import '../../features/currency_converter/data/datasources/frankfurter_remote_datasource_impl.dart';
import '../../features/currency_converter/data/repository/currency_converter_repository_impl.dart';
import '../../features/currency_converter/domain/repository/currency_converter_repository.dart';
import '../../features/currency_converter/domain/usecases/converter_preferences_usecases.dart';
import '../../features/currency_converter/domain/usecases/get_exchange_rate_usecase.dart';
import '../../features/currency_converter/domain/usecases/get_supported_currencies_usecase.dart';
import '../../features/currency_converter/presentation/bloc/currency_converter_bloc.dart';

final GetIt getIt = GetIt.instance;

/// Builds the app's object graph. [database] lets a widget test pass an
/// in-memory database; the app always opens the on-device one.
Future<void> initDependencyInjection({
  @visibleForTesting AppDatabase? database,
}) async {
  // SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Local Database
  getIt.registerSingleton<AppDatabase>(database ?? AppDatabase());

  // Database Integrity Service
  getIt.registerLazySingleton<DatabaseIntegrityService>(
    () => DatabaseIntegrityService(database: getIt<AppDatabase>()),
  );

  // Budget Engine - Core Service
  getIt.registerLazySingleton<BudgetCalculationService>(
    () => BudgetCalculationService(),
  );
  getIt.registerLazySingleton<SafeToSpendCalculator>(
    () => SafeToSpendCalculator(getIt<BudgetCalculationService>()),
  );

  // Theme Repository + BLoC
  getIt.registerLazySingleton<ThemeRepository>(
    () => ThemeRepository(settingsRepository: getIt<SettingsRepository>()),
  );
  getIt.registerLazySingleton<ThemeBloc>(
    () => ThemeBloc(themeRepository: getIt<ThemeRepository>()),
  );

  // Currency Provider
  getIt.registerLazySingleton<CurrencyProvider>(() => CurrencyProvider());

  // Biometric Initializer
  getIt.registerLazySingleton<BiometricInitializer>(
    () => BiometricInitializer(),
  );

  // App Lock BLoC - authoritative application lock state
  getIt.registerLazySingleton<AppLockBloc>(
    () => AppLockBloc(biometricInitializer: getIt<BiometricInitializer>()),
  );

  // Onboarding Feature - Datasources
  getIt.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(
      sharedPreferences: getIt<SharedPreferences>(),
      database: getIt<AppDatabase>(),
    ),
  );

  // Budget Feature - Datasources
  getIt.registerLazySingleton<BudgetLocalDataSource>(
    () => BudgetLocalDataSourceImpl(
      database: getIt<AppDatabase>(),
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );

  // Onboarding Feature - Repositories
  getIt.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(
      localDataSource: getIt<OnboardingLocalDataSource>(),
    ),
  );

  // Budget Feature - Repositories
  getIt.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(
      localDataSource: getIt<BudgetLocalDataSource>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  // Onboarding Feature - Use Cases
  getIt.registerLazySingleton<CheckFirstLaunchUseCase>(
    () => CheckFirstLaunchUseCase(getIt<OnboardingRepository>()),
  );

  getIt.registerLazySingleton<CreateBudgetUseCase>(
    () => CreateBudgetUseCase(getIt<OnboardingRepository>()),
  );

  // Budget Feature - Use Cases
  getIt.registerLazySingleton<GetBudgetSummaryUseCase>(
    () => GetBudgetSummaryUseCase(
      repository: getIt<BudgetRepository>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  getIt.registerLazySingleton<ManageBudgetUseCase>(
    () => ManageBudgetUseCase(repository: getIt<BudgetRepository>()),
  );

  getIt.registerLazySingleton<GetBudgetListSummaryUseCase>(
    () => GetBudgetListSummaryUseCase(repository: getIt<BudgetRepository>()),
  );

  getIt.registerLazySingleton<RecalculateRemainingAmountsUseCase>(
    () => RecalculateRemainingAmountsUseCase(
      repository: getIt<BudgetRepository>(),
      calculationService: getIt<BudgetCalculationService>(),
    ),
  );

  // Onboarding Feature - BLoC
  getIt.registerFactory<OnboardingBloc>(
    () => OnboardingBloc(
      createBudgetUseCase: getIt<CreateBudgetUseCase>(),
      budgetRepository: getIt<BudgetRepository>(),
    ),
  );

  // Dashboard Feature - Datasources
  getIt.registerLazySingleton<DashboardLocalDataSource>(
    () => DashboardLocalDataSourceImpl(database: getIt<AppDatabase>()),
  );

  // Dashboard Feature - Repositories
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(
      localDataSource: getIt<DashboardLocalDataSource>(),
    ),
  );

  // Dashboard Feature - Use Cases
  getIt.registerLazySingleton<GetRecentExpensesUseCase>(
    () => GetRecentExpensesUseCase(repository: getIt<DashboardRepository>()),
  );

  getIt.registerLazySingleton<GetSmartInsightsUseCase>(
    () => const GetSmartInsightsUseCase(),
  );

  getIt.registerLazySingleton<BillOccurrenceEnumerator>(
    () => const BillOccurrenceEnumerator(),
  );

  getIt.registerLazySingleton<GetSpendingPaceUseCase>(
    () => GetSpendingPaceUseCase(repository: getIt<DashboardRepository>()),
  );

  getIt.registerLazySingleton<GetSafeToSpendUseCase>(
    () => GetSafeToSpendUseCase(
      budgetRepository: getIt<BudgetRepository>(),
      billRepository: getIt<BillRepository>(),
      dashboardRepository: getIt<DashboardRepository>(),
      calculator: getIt<SafeToSpendCalculator>(),
      enumerator: getIt<BillOccurrenceEnumerator>(),
    ),
  );

  getIt.registerLazySingleton<GetLinkableBillsUseCase>(
    () => GetLinkableBillsUseCase(
      billRepository: getIt<BillRepository>(),
      budgetRepository: getIt<BudgetRepository>(),
      enumerator: getIt<BillOccurrenceEnumerator>(),
    ),
  );

  getIt.registerLazySingleton<GetSpendingTargetsUseCase>(
    () => GetSpendingTargetsUseCase(
      repository: getIt<BudgetRepository>(),
      calculationService: getIt<BudgetCalculationService>(),
      safeToSpend: getIt<GetSafeToSpendUseCase>(),
    ),
  );

  // Dashboard Feature - BLoC
  getIt.registerFactory<DashboardBloc>(
    () => DashboardBloc(
      getBudgetSummaryUseCase: getIt<GetBudgetSummaryUseCase>(),
      getRecentExpensesUseCase: getIt<GetRecentExpensesUseCase>(),
      getSmartInsightsUseCase: getIt<GetSmartInsightsUseCase>(),
      getSpendingTargetsUseCase: getIt<GetSpendingTargetsUseCase>(),
      getSafeToSpendUseCase: getIt<GetSafeToSpendUseCase>(),
      budgetRepository: getIt<BudgetRepository>(),
      billRepository: getIt<BillRepository>(),
      getSpendingPaceUseCase: getIt<GetSpendingPaceUseCase>(),
    ),
  );

  // Categories Feature
  getIt.registerLazySingleton<CategoryLocalDataSource>(
    () => CategoryLocalDataSourceImpl(database: getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(
      localDataSource: getIt<CategoryLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<LoadCategoriesUseCase>(
    () => LoadCategoriesUseCase(repository: getIt<CategoryRepository>()),
  );
  getIt.registerLazySingleton<SaveCategoryUseCase>(
    () => SaveCategoryUseCase(repository: getIt<CategoryRepository>()),
  );
  getIt.registerLazySingleton<ArchiveCategoryUseCase>(
    () => ArchiveCategoryUseCase(repository: getIt<CategoryRepository>()),
  );
  getIt.registerLazySingleton<DeleteCategoryUseCase>(
    () => DeleteCategoryUseCase(repository: getIt<CategoryRepository>()),
  );
  getIt.registerFactory<CategoryBloc>(
    () => CategoryBloc(
      loadCategories: getIt<LoadCategoriesUseCase>(),
      saveCategory: getIt<SaveCategoryUseCase>(),
      archiveCategory: getIt<ArchiveCategoryUseCase>(),
      deleteCategory: getIt<DeleteCategoryUseCase>(),
    ),
  );

  // Expense Feature - Datasources
  getIt.registerLazySingleton<ExpenseLocalDataSource>(
    () => ExpenseLocalDataSourceImpl(database: getIt<AppDatabase>()),
  );

  // Expense Feature - Repositories
  getIt.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(
      localDataSource: getIt<ExpenseLocalDataSource>(),
      budgetRepository: getIt<BudgetRepository>(),
    ),
  );

  // Expense Feature - Use Cases
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
  getIt.registerLazySingleton<GetExpensesForBudgetsUseCase>(
    () => GetExpensesForBudgetsUseCase(repository: getIt<ExpenseRepository>()),
  );
  getIt.registerLazySingleton<GetCategoriesUseCase>(
    () => GetCategoriesUseCase(repository: getIt<ExpenseRepository>()),
  );

  // Expense Feature - BLoC
  getIt.registerFactory<ExpenseBloc>(
    () => ExpenseBloc(
      createExpenseUseCase: getIt<CreateExpenseUseCase>(),
      updateExpenseUseCase: getIt<UpdateExpenseUseCase>(),
      deleteExpenseUseCase: getIt<DeleteExpenseUseCase>(),
      getExpenseByIdUseCase: getIt<GetExpenseByIdUseCase>(),
      getExpensesUseCase: getIt<GetExpensesUseCase>(),
      getCategoriesUseCase: getIt<GetCategoriesUseCase>(),
      budgetRepository: getIt<BudgetRepository>(),
    ),
  );

  // Expense History - Pure use cases
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
  getIt.registerLazySingleton<PageExpensesUseCase>(
    () => const PageExpensesUseCase(),
  );

  // Expense History - BLoC
  getIt.registerFactory<ExpenseHistoryBloc>(
    () => ExpenseHistoryBloc(
      getExpensesUseCase: getIt<GetExpensesUseCase>(),
      getExpensesForBudgetsUseCase: getIt<GetExpensesForBudgetsUseCase>(),
      getCategoriesUseCase: getIt<GetCategoriesUseCase>(),
      searchExpensesUseCase: getIt<SearchExpensesUseCase>(),
      filterExpensesUseCase: getIt<FilterExpensesUseCase>(),
      sortExpensesUseCase: getIt<SortExpensesUseCase>(),
      calculateExpenseSummaryUseCase: getIt<CalculateExpenseSummaryUseCase>(),
      pageExpensesUseCase: getIt<PageExpensesUseCase>(),
      budgetRepository: getIt<BudgetRepository>(),
    ),
  );

  // Reports Feature - Repository
  getIt.registerLazySingleton<ReportsRepository>(
    () => ReportsRepositoryImpl(
      getExpensesUseCase: getIt<GetExpensesUseCase>(),
      getCategoriesUseCase: getIt<GetCategoriesUseCase>(),
      filterExpensesUseCase: getIt<FilterExpensesUseCase>(),
      budgetRepository: getIt<BudgetRepository>(),
    ),
  );

  // Reports Feature - Services
  getIt.registerLazySingleton<AnalyticsService>(() => const AnalyticsService());
  getIt.registerLazySingleton<ReportInsightGenerator>(
    () => const ReportInsightGenerator(),
  );

  // Reports Feature - Use Case
  getIt.registerLazySingleton<GetReportDataUseCase>(
    () => GetReportDataUseCase(
      repository: getIt<ReportsRepository>(),
      analyticsService: getIt<AnalyticsService>(),
    ),
  );

  // Reports Feature - BLoC
  getIt.registerFactory<ReportsBloc>(
    () => ReportsBloc(
      getReportDataUseCase: getIt<GetReportDataUseCase>(),
      insightGenerator: getIt<ReportInsightGenerator>(),
      budgetRepository: getIt<BudgetRepository>(),
    ),
  );

  // ============================================================
  //  Phase 8 – Settings, Notifications, Security & Data Management
  // ============================================================

  // Settings Feature – Datasources
  getIt.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSourceImpl(
      database: getIt<AppDatabase>(),
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );

  // Settings Feature – Repositories
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(
      localDataSource: getIt<SettingsLocalDataSource>(),
    ),
  );

  // Settings Feature – Services
  getIt.registerLazySingleton<NotificationService>(
    () => NotificationService(
      plugin: FlutterLocalNotificationsPlugin(),
      spendingTargetsUseCase: getIt<GetSpendingTargetsUseCase>(),
      // Resolved on use: BillReminderService is registered further down.
      rescheduleBillReminders: () =>
          getIt<BillReminderService>().rescheduleAll(),
    ),
  );
  getIt.registerLazySingleton<BiometricService>(() => BiometricService());
  getIt.registerLazySingleton<ExportService>(
    () => ExportService(database: getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<BackupService>(
    () => BackupService(
      database: getIt<AppDatabase>(),
      recalculateRemaining: getIt<RecalculateRemainingAmountsUseCase>(),
    ),
  );
  getIt.registerLazySingleton<ImportService>(
    () => ImportService(
      database: getIt<AppDatabase>(),
      recalculateRemaining: getIt<RecalculateRemainingAmountsUseCase>(),
    ),
  );

  // Settings Feature – Use Cases
  getIt.registerLazySingleton<LoadSettingsUseCase>(
    () => LoadSettingsUseCase(repository: getIt<SettingsRepository>()),
  );
  getIt.registerLazySingleton<UpdateCurrencyUseCase>(
    () => UpdateCurrencyUseCase(repository: getIt<SettingsRepository>()),
  );
  getIt.registerLazySingleton<UpdateNotificationSettingsUseCase>(
    () => UpdateNotificationSettingsUseCase(
      repository: getIt<SettingsRepository>(),
    ),
  );
  getIt.registerLazySingleton<UpdateBiometricUseCase>(
    () => UpdateBiometricUseCase(repository: getIt<SettingsRepository>()),
  );
  getIt.registerLazySingleton<ExportDataUseCase>(
    () => ExportDataUseCase(exportService: getIt<ExportService>()),
  );
  getIt.registerLazySingleton<ImportDataUseCase>(
    () => ImportDataUseCase(importService: getIt<ImportService>()),
  );
  getIt.registerLazySingleton<BackupDataUseCase>(
    () => BackupDataUseCase(backupService: getIt<BackupService>()),
  );
  getIt.registerLazySingleton<RestoreDataUseCase>(
    () => RestoreDataUseCase(backupService: getIt<BackupService>()),
  );
  getIt.registerLazySingleton<ResetBudgetUseCase>(
    () => ResetBudgetUseCase(
      repository: getIt<BudgetRepository>(),
      billRepository: getIt<BillRepository>(),
    ),
  );
  getIt.registerLazySingleton<ScheduleNotificationsUseCase>(
    () => ScheduleNotificationsUseCase(
      notificationService: getIt<NotificationService>(),
    ),
  );

  // Notification BLoC
  getIt.registerLazySingleton<NotificationBloc>(
    () => NotificationBloc(
      notificationService: getIt<NotificationService>(),
      loadSettingsUseCase: getIt<LoadSettingsUseCase>(),
    ),
  );
  // Settings Feature – BLoC
  getIt.registerFactory<SettingsBloc>(
    () => SettingsBloc(
      loadSettingsUseCase: getIt<LoadSettingsUseCase>(),
      updateCurrencyUseCase: getIt<UpdateCurrencyUseCase>(),
      updateNotificationSettingsUseCase:
          getIt<UpdateNotificationSettingsUseCase>(),
      updateBiometricUseCase: getIt<UpdateBiometricUseCase>(),
      biometricService: getIt<BiometricService>(),
      exportDataUseCase: getIt<ExportDataUseCase>(),
      importDataUseCase: getIt<ImportDataUseCase>(),
      backupDataUseCase: getIt<BackupDataUseCase>(),
      restoreDataUseCase: getIt<RestoreDataUseCase>(),
      resetBudgetUseCase: getIt<ResetBudgetUseCase>(),
      scheduleNotificationsUseCase: getIt<ScheduleNotificationsUseCase>(),
      integrityService: getIt<DatabaseIntegrityService>(),
      // The lock bloc is a singleton above the router; telling it here makes
      // the toggle take effect without a restart.
      onLockPreferenceChanged: (enabled) =>
          getIt<AppLockBloc>().add(AppLockPreferenceChanged(enabled: enabled)),
      onSettingsRestored: () {
        getIt<ThemeBloc>().add(const ThemeLoadRequested());
        getIt<CurrencyProvider>().reload();
        getIt<AppLockBloc>().add(const AppLockSyncRequested());
      },
    ),
  );

  // ============================================================
  //  Phase 9 – Bills & Reminders Feature
  // ============================================================

  // Bills Feature – Datasource
  getIt.registerLazySingleton<BillLocalDataSource>(
    () => BillLocalDataSourceImpl(database: getIt<AppDatabase>()),
  );

  // Bills Feature – Repository
  getIt.registerLazySingleton<BillRepository>(
    () => BillRepositoryImpl(localDataSource: getIt<BillLocalDataSource>()),
  );

  // Bills Feature – Reminder Service
  getIt.registerLazySingleton<BillReminderService>(
    () => BillReminderService(
      plugin: FlutterLocalNotificationsPlugin(),
      repository: getIt<BillRepository>(),
    ),
  );

  // Bills Feature – Use Cases
  getIt.registerLazySingleton<CreateBillUseCase>(
    () => CreateBillUseCase(repository: getIt<BillRepository>()),
  );
  getIt.registerLazySingleton<UpdateBillUseCase>(
    () => UpdateBillUseCase(repository: getIt<BillRepository>()),
  );
  getIt.registerLazySingleton<DeleteBillUseCase>(
    () => DeleteBillUseCase(repository: getIt<BillRepository>()),
  );
  getIt.registerLazySingleton<GetBillsUseCase>(
    () => GetBillsUseCase(repository: getIt<BillRepository>()),
  );
  getIt.registerLazySingleton<GetBillByIdUseCase>(
    () => GetBillByIdUseCase(repository: getIt<BillRepository>()),
  );
  getIt.registerLazySingleton<MarkBillPaidUseCase>(
    () => MarkBillPaidUseCase(repository: getIt<BillRepository>()),
  );
  getIt.registerLazySingleton<MarkBillUnpaidUseCase>(
    () => MarkBillUnpaidUseCase(
      repository: getIt<BillRepository>(),
      expenseRepository: getIt<ExpenseRepository>(),
    ),
  );
  getIt.registerLazySingleton<PayBillUseCase>(
    () => PayBillUseCase(
      billRepository: getIt<BillRepository>(),
      budgetRepository: getIt<BudgetRepository>(),
      expenseRepository: getIt<ExpenseRepository>(),
    ),
  );
  getIt.registerLazySingleton<LinkBillsToBudgetUseCase>(
    () => LinkBillsToBudgetUseCase(
      billRepository: getIt<BillRepository>(),
      budgetRepository: getIt<BudgetRepository>(),
    ),
  );

  // Bills Feature – BLoC
  getIt.registerFactory<BillBloc>(
    () => BillBloc(
      createBillUseCase: getIt<CreateBillUseCase>(),
      updateBillUseCase: getIt<UpdateBillUseCase>(),
      deleteBillUseCase: getIt<DeleteBillUseCase>(),
      getBillsUseCase: getIt<GetBillsUseCase>(),
      getBillByIdUseCase: getIt<GetBillByIdUseCase>(),
      markBillPaidUseCase: getIt<MarkBillPaidUseCase>(),
      markBillUnpaidUseCase: getIt<MarkBillUnpaidUseCase>(),
      payBillUseCase: getIt<PayBillUseCase>(),
      reminderService: getIt<BillReminderService>(),
    ),
  );

  // ============================================================
  //  Phase 10 – App Update Checker
  // ============================================================

  // App Update – Remote Data Source
  getIt.registerLazySingleton<GithubReleaseRemoteDataSource>(
    () => GithubReleaseRemoteDataSourceImpl(),
  );

  // App Update – Repository
  getIt.registerLazySingleton<AppUpdateRepository>(
    () => AppUpdateRepositoryImpl(
      remoteDataSource: getIt<GithubReleaseRemoteDataSource>(),
    ),
  );

  // App Update – Use Case
  getIt.registerLazySingleton<CheckForAppUpdateUseCase>(
    () => CheckForAppUpdateUseCase(repository: getIt<AppUpdateRepository>()),
  );

  // App Update – BLoC
  getIt.registerLazySingleton<AppUpdateBloc>(
    () => AppUpdateBloc(
      checkForAppUpdateUseCase: getIt<CheckForAppUpdateUseCase>(),
    ),
  );

  // ============================================================
  //  Phase 11 – Currency Converter
  // ============================================================

  // Currency Converter – Data Sources
  getIt.registerLazySingleton<CurrencyRemoteDataSource>(
    () => FrankfurterRemoteDataSourceImpl(),
  );
  getIt.registerLazySingleton<CurrencyLocalDataSource>(
    () => CurrencyLocalDataSourceImpl(
      database: getIt<AppDatabase>(),
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );

  // Currency Converter – Repository (cache-first)
  getIt.registerLazySingleton<CurrencyConverterRepository>(
    () => CurrencyConverterRepositoryImpl(
      remoteDataSource: getIt<CurrencyRemoteDataSource>(),
      localDataSource: getIt<CurrencyLocalDataSource>(),
    ),
  );

  // Currency Converter – Use Cases
  getIt.registerLazySingleton<GetSupportedCurrenciesUseCase>(
    () => GetSupportedCurrenciesUseCase(
      repository: getIt<CurrencyConverterRepository>(),
    ),
  );
  getIt.registerLazySingleton<GetExchangeRateUseCase>(
    () => GetExchangeRateUseCase(
      repository: getIt<CurrencyConverterRepository>(),
    ),
  );
  getIt.registerLazySingleton<LoadConverterPreferencesUseCase>(
    () => LoadConverterPreferencesUseCase(
      repository: getIt<CurrencyConverterRepository>(),
    ),
  );
  getIt.registerLazySingleton<SaveConverterPreferencesUseCase>(
    () => SaveConverterPreferencesUseCase(
      repository: getIt<CurrencyConverterRepository>(),
    ),
  );

  // Currency Converter – BLoC (one per visit)
  getIt.registerFactory<CurrencyConverterBloc>(
    () => CurrencyConverterBloc(
      getSupportedCurrencies: getIt<GetSupportedCurrenciesUseCase>(),
      getExchangeRate: getIt<GetExchangeRateUseCase>(),
      loadPreferences: getIt<LoadConverterPreferencesUseCase>(),
      savePreferences: getIt<SaveConverterPreferencesUseCase>(),
    ),
  );
}
