import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/router/app_router.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/quick_add/quick_add_sheet.dart';
import 'package:monivo/features/pay_later/presentation/bloc/pay_later_summary_cubit.dart';
import 'package:monivo/features/widgets/home_widget_service.dart';

import '../../features/expenses/presentation/expense_test_fakes.dart';
import '../../features/pay_later/presentation/fake_pay_later_summary_cubit.dart';

class _StaticDashboardBloc extends Bloc<DashboardEvent, DashboardState>
    implements DashboardBloc {
  _StaticDashboardBloc() : super(const DashboardEmpty()) {
    on<DashboardEvent>((_, _) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeManageBudget implements ManageBudgetUseCase {
  @override
  Future<BudgetEntity?> getActive() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<ManageBudgetUseCase>(_FakeManageBudget());
    final expenses = MemoryExpenseRepository();
    final budgets = StubBudgetRepository([
      testBudget(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 31)),
    ]);
    getIt.registerFactory<ExpenseBloc>(
      () => memoryExpenseBloc(expenses, budgets),
    );
  });
  tearDown(() => getIt.reset());

  test('"Add expense" on the widget opens Home with quick add', () {
    for (final link in [
      'monivo://add_expense',
      'homewidget://expense/add',
      'monivo://app/add',
    ]) {
      expect(resolveWidgetUriToRoute(Uri.parse(link)), widgetAddExpensePath);
    }
    final uri = Uri.parse(widgetAddExpensePath);
    expect(uri.path, AppRouter.homePath);
    expect(uri.queryParameters, {'quickAdd': '1'});
    // The rest of the widget still opens Home alone.
    expect(
      resolveWidgetUriToRoute(Uri.parse('monivo://open')),
      AppRouter.homePath,
    );
  });

  Widget dashboard({required bool openQuickAdd}) => MultiBlocProvider(
    providers: [
      BlocProvider<DashboardBloc>(create: (_) => _StaticDashboardBloc()),
      BlocProvider<PayLaterSummaryCubit>(
        create: (_) => FakePayLaterSummaryCubit(),
      ),
    ],
    child: DashboardScreen(openQuickAdd: openQuickAdd),
  );

  testWidgets('a cold start from the widget opens quick add over Home once', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: dashboard(openQuickAdd: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(QuickAddSheet), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsNothing);

    // Rebuilt with the same location (a tab switch back): not again.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: dashboard(openQuickAdd: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsNothing);
  });

  testWidgets('Home opened any other way does not', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: dashboard(openQuickAdd: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsNothing);
  });

  testWidgets('a warm tap opens one sheet over the screen, never two', (
    tester,
  ) async {
    final router = GoRouter(
      navigatorKey: AppRouter.rootNavigatorKey,
      initialLocation: '/somewhere',
      routes: [
        GoRoute(
          path: '/somewhere',
          builder: (_, _) => const Scaffold(body: Text('Budget details')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );

    AppRouter.openFromWidget(widgetAddExpensePath);
    await tester.pumpAndSettle();
    AppRouter.openFromWidget(widgetAddExpensePath);
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddSheet), findsOneWidget);
    // What was on screen is still there underneath.
    expect(find.text('Budget details', skipOffstage: false), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsNothing);
    expect(find.text('Budget details'), findsOneWidget);
  });
}
