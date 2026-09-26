import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../di/injection.dart';
import '../../features/app_update/presentation/widgets/update_dialog_service.dart';
import 'app_page_transitions.dart';
import 'app_shell.dart';
import '../../features/budget/presentation/pages/budget_details_screen.dart';
import '../../features/budget/presentation/pages/budget_form_screen.dart';
import '../../features/budget/presentation/pages/budget_list_screen.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/dashboard/presentation/bloc/dashboard_event.dart';
import '../../features/dashboard/presentation/pages/dashboard_screen.dart';
import '../../features/expenses/presentation/bloc/expense_bloc.dart';
import '../../features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import '../../features/expenses/presentation/history/pages/expense_history_screen.dart';
import '../../features/expenses/presentation/pages/expense_details_screen.dart';
import '../../features/expenses/presentation/pages/expense_form_screen.dart';
import '../../features/onboarding/domain/usecases/check_first_launch_usecase.dart';
import '../../features/onboarding/presentation/pages/onboarding_screen.dart';
import '../../features/reports/presentation/bloc/reports_bloc.dart';
import '../../features/reports/presentation/pages/reports_screen.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../features/settings/presentation/pages/palette_selection_screen.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';
import '../../features/bills/presentation/bloc/bill_bloc.dart';
import '../../features/bills/presentation/pages/bills_list_screen.dart';
import '../../features/bills/presentation/pages/bill_form_screen.dart';
import '../../features/bills/presentation/pages/bill_details_screen.dart';
import '../../features/categories/presentation/bloc/category_bloc.dart';
import '../../features/categories/presentation/pages/category_management_screen.dart';
import '../../features/widgets/home_widget_service.dart';

/// Sentinel value for the widget-launched add-expense deep link.
const String widgetAddExpensePath = '/app/expenses/add';

class AppRouter {
  AppRouter._();

  static const String onboardingPath = '/onboarding';
  static const String appPath = '/app';
  static const String homePath = '/app/home';
  static const String expensesPath = '/app/expenses';
  static const String reportsPath = '/app/reports';
  static const String budgetsPath = '/app/budgets';
  static const String settingsPath = '/app/settings';
  static const String billsPath = '/app/bills';
  static const String categoriesPath = '/app/categories';
  static const String palettePath = '/app/settings/palette';

  /// The root [Navigator]. Screens that must cover the bottom navigation
  /// (forms, details, pickers) are pushed here with `parentNavigatorKey`.
  static GlobalKey<NavigatorState> get rootNavigatorKey =>
      UpdateDialogService.rootNavigatorKey;

  static final GoRouter router = GoRouter(
    navigatorKey: UpdateDialogService.rootNavigatorKey,
    initialLocation: homePath,
    redirect: (context, state) async {
      final checkFirstLaunch = getIt<CheckFirstLaunchUseCase>();
      final isFirstLaunch = await checkFirstLaunch();

      final isOnboardingRoute = state.matchedLocation == onboardingPath;

      if (isFirstLaunch && !isOnboardingRoute) {
        return onboardingPath;
      }
      if (!isFirstLaunch && isOnboardingRoute) {
        return homePath;
      }

      // ── Widget deep link: Add Expense ─────────────────────────────────
      // Check if the app was launched from a home-screen widget.
      // consumePendingWidgetRoute() returns a non-null path only once.
      final widgetRoute = consumePendingWidgetRoute();
      if (widgetRoute != null && !isOnboardingRoute && !isFirstLaunch) {
        return widgetRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: onboardingPath,
        name: 'onboarding',
        pageBuilder: (context, state) => AppPageTransitions.page(
          context: context,
          state: state,
          transition: AppTransition.fadeThrough,
          child: const OnboardingScreen(),
        ),
      ),

      // ── Standalone routes (full-screen, not bottom-nav tabs) ──────────
      // These must come before the shell route so they match first when the
      // user pushes a secondary screen on top of the current tab.
      GoRoute(
        path: budgetsPath,
        name: 'budgets',
        pageBuilder: (context, state) => AppPageTransitions.page(
          context: context,
          state: state,
          transition: AppTransition.sharedAxisHorizontal,
          child: const BudgetListScreen(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            name: 'createBudget',
            pageBuilder: (context, state) => AppPageTransitions.page(
              context: context,
              state: state,
              transition: AppTransition.fadeScale,
              child: const BudgetFormScreen(),
            ),
          ),
          GoRoute(
            path: ':id',
            name: 'budgetDetails',
            pageBuilder: (context, state) => AppPageTransitions.page(
              context: context,
              state: state,
              transition: AppTransition.sharedAxisHorizontal,
              child: BudgetDetailsScreen(budgetId: state.pathParameters['id']!),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                name: 'editBudget',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  context: context,
                  state: state,
                  transition: AppTransition.fadeScale,
                  child: BudgetFormScreen(budgetId: state.pathParameters['id']),
                ),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: billsPath,
        name: 'bills',
        pageBuilder: (context, state) => AppPageTransitions.page(
          context: context,
          state: state,
          transition: AppTransition.sharedAxisHorizontal,
          child: BlocProvider(
            create: (context) => getIt<BillBloc>(),
            child: const BillsListScreen(),
          ),
        ),
        routes: [
          GoRoute(
            path: 'add',
            name: 'addBill',
            pageBuilder: (context, state) => AppPageTransitions.page(
              context: context,
              state: state,
              transition: AppTransition.fadeScale,
              child: BlocProvider(
                create: (context) => getIt<BillBloc>(),
                child: const BillFormScreen(),
              ),
            ),
          ),
          GoRoute(
            path: 'edit/:id',
            name: 'editBill',
            pageBuilder: (context, state) => AppPageTransitions.page(
              context: context,
              state: state,
              transition: AppTransition.fadeScale,
              child: BlocProvider(
                create: (context) => getIt<BillBloc>(),
                child: BillFormScreen(billId: state.pathParameters['id']),
              ),
            ),
          ),
          GoRoute(
            path: ':id',
            name: 'billDetails',
            pageBuilder: (context, state) => AppPageTransitions.page(
              context: context,
              state: state,
              transition: AppTransition.sharedAxisHorizontal,
              child: BlocProvider(
                create: (context) => getIt<BillBloc>(),
                child: BillDetailsScreen(billId: state.pathParameters['id']!),
              ),
            ),
          ),
        ],
      ),

      GoRoute(
        path: categoriesPath,
        name: 'categories',
        pageBuilder: (context, state) => AppPageTransitions.page(
          context: context,
          state: state,
          transition: AppTransition.sharedAxisHorizontal,
          child: BlocProvider(
            create: (context) => getIt<CategoryBloc>(),
            child: const CategoryManagementScreen(),
          ),
        ),
      ),

      // ── Shell route (bottom-navigation tabs) ─────────────────────────
      StatefulShellRoute(
        // The shell itself is a page so arriving from onboarding uses the
        // app's own fade-through instead of the platform default.
        pageBuilder: (context, state, navigationShell) =>
            AppPageTransitions.page(
              context: context,
              state: state,
              transition: AppTransition.fadeThrough,
              child: AppShell(navigationShell: navigationShell),
            ),
        // Branches stay mounted (like an IndexedStack) but cross-fade when
        // the user switches tabs.
        navigatorContainerBuilder: (context, navigationShell, children) =>
            FadeThroughBranchContainer(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          // Home / Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: homePath,
                name: 'dashboard',
                builder: (context, state) => BlocProvider(
                  create: (context) =>
                      getIt<DashboardBloc>()..add(const DashboardLoadData()),
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),
          // Expenses
          StatefulShellBranch(
            // Preloaded so the first visit fades in with data instead of a
            // skeleton; everything is local so the cost is a few queries.
            preload: true,
            routes: [
              GoRoute(
                path: expensesPath,
                name: 'expenses',
                builder: (context, state) => MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (context) => getIt<ExpenseHistoryBloc>(),
                    ),
                    BlocProvider(create: (context) => getIt<ExpenseBloc>()),
                  ],
                  child: const ExpenseHistoryScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'addExpense',
                    // Full-screen over the bottom bar, like the bill and
                    // budget forms, and reachable from any tab without
                    // switching the shell to Expenses.
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => AppPageTransitions.page(
                      context: context,
                      state: state,
                      transition: AppTransition.fadeScale,
                      child: BlocProvider(
                        create: (context) => getIt<ExpenseBloc>(),
                        child: ExpenseFormScreen(
                          copyFromId: state.uri.queryParameters['copy'],
                        ),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    name: 'editExpense',
                    // Full-screen over the bottom bar, like the bill and
                    // budget forms, and reachable from any tab without
                    // switching the shell to Expenses.
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => AppPageTransitions.page(
                      context: context,
                      state: state,
                      transition: AppTransition.fadeScale,
                      child: BlocProvider(
                        create: (context) => getIt<ExpenseBloc>(),
                        child: ExpenseFormScreen(
                          expenseId: state.pathParameters['id'],
                        ),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'expenseDetails',
                    // Full-screen over the bottom bar, like the bill and
                    // budget forms, and reachable from any tab without
                    // switching the shell to Expenses.
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => AppPageTransitions.page(
                      context: context,
                      state: state,
                      transition: AppTransition.sharedAxisHorizontal,
                      child: BlocProvider(
                        create: (context) => getIt<ExpenseBloc>(),
                        child: ExpenseDetailsScreen(
                          expenseId: state.pathParameters['id']!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Reports
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: reportsPath,
                name: 'reports',
                builder: (context, state) => BlocProvider(
                  create: (context) => getIt<ReportsBloc>(),
                  child: const ReportsScreen(),
                ),
              ),
            ],
          ),
          // Settings
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: settingsPath,
                name: 'settings',
                builder: (context, state) => BlocProvider(
                  create: (context) => getIt<SettingsBloc>(),
                  child: const SettingsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'palette',
                    name: 'palette',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => AppPageTransitions.page(
                      context: context,
                      state: state,
                      transition: AppTransition.sharedAxisHorizontal,
                      child: const PaletteSelectionScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
