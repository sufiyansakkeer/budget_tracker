import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/core/widgets/app_surface.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/pages/expense_details_screen.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_undo.dart';

import '../expense_test_fakes.dart';

void main() {
  late MemoryExpenseRepository expenses;
  late StubBudgetRepository budgets;
  final day = DateTime(2026, 10, 6);
  final dinner = ExpenseEntity(
    id: 'e1',
    budgetId: 'muscat',
    amount: 12.75,
    categoryId: 'food',
    note: 'Dinner',
    date: day,
    time: day.add(const Duration(hours: 20, minutes: 15)),
    tags: const ['friends'],
    createdAt: day,
    updatedAt: day,
  );

  setUp(() async {
    await getIt.reset();
    expenses = MemoryExpenseRepository()..store[dinner.id] = dinner;
    budgets = StubBudgetRepository([
      testBudget(
        id: 'muscat',
        name: 'Muscat',
        currency: 'OMR',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
      ),
    ]);
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(repository: budgets),
    );
    ExpenseUndo.blocFactory = () => memoryExpenseBloc(expenses, budgets);
  });
  tearDown(() async {
    ExpenseUndo.blocFactory = () => getIt<ExpenseBloc>();
    await getIt.reset();
  });

  Future<void> pumpDetails(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = memoryExpenseBloc(expenses, budgets);
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: '/app/expenses',
      routes: [
        GoRoute(
          path: '/app/expenses',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/details'),
                child: const Text('List'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/details',
          builder: (_, _) => BlocProvider<ExpenseBloc>.value(
            value: bloc,
            child: const ExpenseDetailsScreen(expenseId: 'e1'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the expense on one surface, in its budget\'s currency', (
    tester,
  ) async {
    await pumpDetails(tester);

    expect(find.byType(AppSurface), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text(AppMoney.format(12.75, currency: 'OMR')), findsOneWidget);
    expect(find.text('Muscat'), findsOneWidget);
    // The locale's own time format (it puts a narrow space before PM).
    expect(find.text(DateFormat.jm().format(dinner.time)), findsOneWidget);
    expect(find.text('#friends'), findsOneWidget);
  });

  testWidgets('a failed read offers a retry, not "not found"', (tester) async {
    expenses.failReadById = 'database is locked';
    await pumpDetails(tester);

    expect(find.text("Couldn't open this expense"), findsOneWidget);
    expect(find.text('Expense not found'), findsNothing);
    expect(find.textContaining('database is locked'), findsNothing);

    expenses.failReadById = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsWidgets);
  });

  testWidgets('delete asks nothing, closes, and Undo brings it back', (
    tester,
  ) async {
    await pumpDetails(tester);
    await tester.tap(find.byKey(const Key('deleteExpenseButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ExpenseDetailsScreen), findsNothing);
    expect(expenses.store, isEmpty);
    expect(find.byKey(const Key('undoDeleteSnackBar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('undoDeleteAction')));
    await tester.pumpAndSettle();
    expect(expenses.store['e1'], dinner);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
      await pumpDetails(tester, size: Size(width, 900), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
