import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/pages/expense_form_screen.dart';

import '../expense_test_fakes.dart';

void main() {
  late MemoryExpenseRepository expenses;
  late StubBudgetRepository budgets;

  setUp(() async {
    await getIt.reset();
    expenses = MemoryExpenseRepository();
    final today = DateTime.now();
    budgets = StubBudgetRepository([
      testBudget(
        start: DateTime(today.year, today.month, today.day - 20),
        end: DateTime(today.year, today.month, today.day + 10),
      ),
    ]);
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(repository: budgets),
    );
  });
  tearDown(() => getIt.reset());

  Future<ExpenseBloc> pumpForm(
    WidgetTester tester, {
    String? expenseId,
    ExpensePrefill? prefill,
  }) async {
    final bloc = memoryExpenseBloc(expenses, budgets);
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: '/app/home',
      routes: [
        GoRoute(
          path: '/app/home',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/form'),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/form',
          builder: (_, _) => BlocProvider<ExpenseBloc>.value(
            value: bloc,
            child: ExpenseFormScreen(expenseId: expenseId, prefill: prefill),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    return bloc;
  }

  Finder amountField() => find.byType(TextFormField).first;

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();
  }

  group('ExpensePrefill.fromQuery', () {
    test('reads what quick add hands over', () {
      final p = ExpensePrefill.fromQuery({
        'amount': '42.5',
        'category': 'fuel',
        'date': '2026-10-07',
        'budget': 'personal',
      });
      expect(p.amount, '42.5');
      expect(p.categoryId, 'fuel');
      expect(p.date, DateTime(2026, 10, 7));
      expect(p.budgetId, 'personal');
    });

    test('ignores anything malformed', () {
      final p = ExpensePrefill.fromQuery({'amount': 'abc', 'date': 'soon'});
      expect(p.amount, isNull);
      expect(p.date, isNull);
      expect(ExpensePrefill.fromQuery(const {}).isEmpty, isTrue);
    });
  });

  testWidgets('"More details" arrives filled in and saves as entered', (
    tester,
  ) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final day = DateTime(yesterday.year, yesterday.month, yesterday.day);
    await pumpForm(
      tester,
      prefill: ExpensePrefill(
        amount: '42',
        categoryId: 'fuel',
        date: day,
        budgetId: 'personal',
      ),
    );

    expect(find.text('42'), findsOneWidget);
    final fuel = tester.widget<ChoiceChip>(
      find.byKey(const Key('category_fuel')),
    );
    expect(fuel.selected, isTrue);

    await tapSave(tester);
    final saved = expenses.store.values.single;
    expect(saved.amount, 42);
    expect(saved.categoryId, 'fuel');
    expect(saved.date, day);
    expect(saved.budgetId, 'personal');
  });

  testWidgets('the amount is checked on save, not while typing', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(amountField(), '0');
    await tester.pump();
    expect(find.text('Amount must be greater than zero'), findsNothing);

    await tapSave(tester);
    expect(find.text('Amount must be greater than zero'), findsOneWidget);
    expect(expenses.store, isEmpty);

    // Typing again clears the message until the next save.
    await tester.enterText(amountField(), '05');
    await tester.pump();
    expect(find.text('Amount must be greater than zero'), findsNothing);
  });

  testWidgets('a save closes the form at once with a short note', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(amountField(), '120');
    await tester.tap(find.byKey(const Key('category_food')));
    await tester.pump();
    await tapSave(tester);

    expect(expenses.store.values.single.amount, 120);
    expect(find.byType(ExpenseFormScreen), findsNothing);
    expect(find.text('Expense added'), findsOneWidget);
  });

  testWidgets('closing an untouched form needs no confirmation', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsNothing);
  });

  testWidgets('closing with something entered asks first', (tester) async {
    await pumpForm(tester);
    await tester.enterText(amountField(), '75');
    await tester.pump();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this expense?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(find.text('75'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsNothing);
    expect(expenses.store, isEmpty);
  });

  testWidgets('the back gesture asks too, even after only a note', (
    tester,
  ) async {
    await pumpForm(tester);
    // The note sits below the fold of a lazily built list.
    final note = find.widgetWithText(TextField, 'Note');
    await tester.scrollUntilVisible(
      note,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(note, 'Taxi');
    await tester.pump();

    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(find.text('Discard this expense?'), findsOneWidget);
  });

  testWidgets('an unchanged edit closes quietly; a changed one asks', (
    tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    expenses.store['e1'] = ExpenseEntity(
      id: 'e1',
      budgetId: 'personal',
      amount: 300,
      categoryId: 'food',
      note: 'Dinner',
      date: day,
      time: day.add(const Duration(hours: 20)),
      createdAt: day,
      updatedAt: day,
    );
    await pumpForm(tester, expenseId: 'e1');
    expect(find.text('300'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.enterText(amountField(), '350');
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });
}
