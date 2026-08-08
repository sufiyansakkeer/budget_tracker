import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../di/injection.dart';
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
import '../../features/settings/presentation/pages/settings_screen.dart';

class AppRouter {
  AppRouter._();

  static const String onboardingPath = '/onboarding';
  static const String appPath = '/app';
  static const String homePath = '/app/home';
  static const String expensesPath = '/app/expenses';
  static const String reportsPath = '/app/reports';
  static const String budgetsPath = '/app/budgets';
  static const String morePath = '/app/more';

  static final GoRouter router = GoRouter(
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
      return null;
    },
    routes: [
      GoRoute(
        path: onboardingPath,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
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
          // Expenses (History)
          StatefulShellBranch(
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
                    builder: (context, state) => BlocProvider(
                      create: (context) => getIt<ExpenseBloc>(),
                      child: const ExpenseFormScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    name: 'editExpense',
                    builder: (context, state) => BlocProvider(
                      create: (context) => getIt<ExpenseBloc>(),
                      child: ExpenseFormScreen(
                        expenseId: state.pathParameters['id'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'expenseDetails',
                    builder: (context, state) => BlocProvider(
                      create: (context) => getIt<ExpenseBloc>(),
                      child: ExpenseDetailsScreen(
                        expenseId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Reports
          StatefulShellBranch(
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
          // Budgets
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: budgetsPath,
                name: 'budgets',
                builder: (context, state) => const BudgetListScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    name: 'createBudget',
                    builder: (context, state) => const BudgetFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'budgetDetails',
                    builder: (context, state) => BudgetDetailsScreen(
                      budgetId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'editBudget',
                        builder: (context, state) => BudgetFormScreen(
                          budgetId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // More (Settings)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: morePath,
                name: 'more',
                builder: (context, state) => BlocProvider(
                  create: (context) => getIt<SettingsBloc>(),
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
