import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../di/injection.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/dashboard/presentation/pages/dashboard_screen.dart';
import '../../features/expenses/presentation/bloc/expense_bloc.dart';
import '../../features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import '../../features/expenses/presentation/history/pages/expense_history_screen.dart';
import '../../features/expenses/presentation/pages/expense_details_screen.dart';
import '../../features/expenses/presentation/pages/expense_form_screen.dart';
import '../../features/expenses/presentation/pages/expenses_list_screen.dart';
import '../../features/onboarding/domain/usecases/check_first_launch_usecase.dart';
import '../../features/onboarding/presentation/pages/onboarding_screen.dart';

class AppRouter {
  AppRouter._();

  static const String onboardingPath = '/onboarding';
  static const String dashboardPath = '/';
  static const String expensesPath = '/expenses';
  static const String reportsPath = '/reports';
  static const String settingsPath = '/settings';

  static final GoRouter router = GoRouter(
    initialLocation: dashboardPath,
    redirect: (context, state) async {
      final checkFirstLaunch = getIt<CheckFirstLaunchUseCase>();
      final isFirstLaunch = await checkFirstLaunch();

      final isOnboardingRoute = state.matchedLocation == onboardingPath;

      if (isFirstLaunch && !isOnboardingRoute) {
        return onboardingPath;
      }
      if (!isFirstLaunch && isOnboardingRoute) {
        return dashboardPath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: onboardingPath,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: dashboardPath,
        name: 'dashboard',
        builder: (context, state) => BlocProvider(
          create: (context) => getIt<DashboardBloc>(),
          child: const DashboardScreen(),
        ),
      ),
      GoRoute(
        path: expensesPath,
        name: 'expenses',
        builder: (context, state) => BlocProvider(
          create: (context) => getIt<ExpenseBloc>(),
          child: const ExpensesListScreen(),
        ),
        routes: [
          GoRoute(
            path: 'history',
            name: 'expenseHistory',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (context) => getIt<ExpenseHistoryBloc>()),
                BlocProvider(create: (context) => getIt<ExpenseBloc>()),
              ],
              child: const ExpenseHistoryScreen(),
            ),
          ),
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
              child: ExpenseFormScreen(expenseId: state.pathParameters['id']),
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
      GoRoute(
        path: reportsPath,
        name: 'reports',
        builder: (context, state) => const PlaceholderScreen(title: 'Reports'),
      ),
      GoRoute(
        path: settingsPath,
        name: 'settings',
        builder: (context, state) => const PlaceholderScreen(title: 'Settings'),
      ),
    ],
  );
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title Feature Placeholder',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
