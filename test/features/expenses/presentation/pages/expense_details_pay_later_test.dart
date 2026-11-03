import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/pages/expense_details_screen.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_undo.dart';
import 'package:monivo/features/pay_later/domain/entities/purchase_change_impact.dart';

import '../expense_test_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../../helpers/pay_later_fixtures.dart';

/// Expense details for a purchase on a Pay later tab (spec §5, §7).
void main() {
  late MemoryExpenseRepository expenses;
  late StubBudgetRepository budgets;
  late FakeTabPurchaseUseCase purchases;
  final day = DateTime(2026, 10, 6);
  final dinner = ExpenseEntity(
    id: 'e1',
    budgetId: 'muscat',
    amount: 3.5,
    categoryId: 'food',
    note: 'Dinner',
    date: day,
    time: day.add(const Duration(hours: 20)),
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
    purchases = FakeTabPurchaseUseCase();
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(
        repository: budgets,
        reconcileTabs: FakeReconcileTabUseCase(),
      ),
    );
    ExpenseUndo.blocFactory = () =>
        memoryExpenseBloc(expenses, budgets, tabPurchases: purchases);
  });
  tearDown(() async {
    ExpenseUndo.blocFactory = () => getIt<ExpenseBloc>();
    await getIt.reset();
  });

  Future<void> pumpDetails(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = memoryExpenseBloc(expenses, budgets, tabPurchases: purchases);
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
        GoRoute(
          path: '/app/pay-later/:id',
          builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text('Tab ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  testWidgets('a purchase on a tab says where and how much is paid, and '
      'opens the tab', (tester) async {
    purchases.tabInfos['e1'] = (
      tab: payLaterTab('t1', name: 'Campus cafeteria'),
      paid: 2.0,
    );
    await pumpDetails(tester);

    final row = find.byKey(const Key('expenseTabRow'));
    expect(row, findsOneWidget);
    final paid = CurrencyFormatter.format(2, code: 'OMR');
    final total = CurrencyFormatter.format(3.5, code: 'OMR');
    expect(
      find.descendant(
        of: row,
        matching: find.text('On Campus cafeteria · paid $paid of $total'),
      ),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Tab t1'), findsOneWidget);
  });

  testWidgets('coming back from the tab re-reads what is paid (T9)', (
    tester,
  ) async {
    final tab = payLaterTab('t1', name: 'Campus cafeteria');
    purchases.tabInfos['e1'] = (tab: tab, paid: 2.0);
    await pumpDetails(tester);
    final row = find.byKey(const Key('expenseTabRow'));
    await tester.tap(row);
    await tester.pumpAndSettle();

    // A payment recorded on the tab screen.
    purchases.tabInfos['e1'] = (tab: tab, paid: 3.5);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final paid = CurrencyFormatter.format(3.5, code: 'OMR');
    expect(
      find.descendant(
        of: row,
        matching: find.text('On Campus cafeteria · paid $paid of $paid'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an expense on no tab has no tab row', (tester) async {
    await pumpDetails(tester);

    expect(find.text('Dinner'), findsWidgets);
    expect(find.byKey(const Key('expenseTabRow')), findsNothing);
  });

  testWidgets('deleting a paid purchase asks first and offers no Undo', (
    tester,
  ) async {
    purchases.tabIds['e1'] = 't1';
    purchases.impactFor = (q) => q.deleting
        ? const PurchaseChangeImpact(
            paidOnIt: 2,
            movesTo: [],
            becomesCredit: 2,
            currency: 'OMR',
          )
        : null;
    await pumpDetails(tester);

    await tester.tap(find.byKey(const Key('deleteExpenseButton')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this purchase?'), findsOneWidget);
    expect(find.textContaining('stay on the tab as credit'), findsOneWidget);

    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();
    expect(purchases.calls, isNot(contains('delete:e1')));
    expect(find.byType(ExpenseDetailsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('deleteExpenseButton')));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Delete'));
    await tester.pumpAndSettle();

    expect(purchases.calls, contains('delete:e1'));
    expect(find.byType(ExpenseDetailsScreen), findsNothing);
    expect(find.text('Expense deleted'), findsOneWidget);
    expect(find.byKey(const Key('undoDeleteAction')), findsNothing);
  });

  testWidgets('an unpaid tab purchase deletes at once, and Undo puts it back '
      'on its tab', (tester) async {
    purchases.tabIds['e1'] = 't1';
    purchases.impactFor = (q) => const PurchaseChangeImpact(
      paidOnIt: 0,
      movesTo: [],
      becomesCredit: 0,
      currency: 'OMR',
    );
    await pumpDetails(tester);

    await tester.tap(find.byKey(const Key('deleteExpenseButton')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(purchases.calls, contains('delete:e1'));

    await tester.tap(find.byKey(const Key('undoDeleteAction')));
    await tester.pumpAndSettle();
    expect(purchases.calls, contains('restore:e1:t1'));
  });

  testWidgets("a payments check that fails doesn't delete", (tester) async {
    purchases.tabIds['e1'] = 't1';
    purchases.impactError = Exception('database is locked');
    await pumpDetails(tester);

    await tester.tap(find.byKey(const Key('deleteExpenseButton')));
    await tester.pumpAndSettle();

    expect(
      // Neutral (M5): the read failed, so it isn't known to be on a tab.
      find.text("Couldn't delete the expense. Try again."),
      findsOneWidget,
    );
    expect(purchases.calls, isNot(contains('delete:e1')));
    expect(find.byType(ExpenseDetailsScreen), findsOneWidget);
  });
  testWidgets('a second tap on Delete while payments are being checked does '
      'nothing', (tester) async {
    purchases.tabIds['e1'] = 't1';
    final read = Completer<void>();
    purchases.impactGate = read.future;
    purchases.impactFor = (q) => const PurchaseChangeImpact(
      paidOnIt: 2,
      movesTo: [],
      becomesCredit: 2,
      currency: 'OMR',
    );
    await pumpDetails(tester);

    await tester.tap(find.byKey(const Key('deleteExpenseButton')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('deleteExpenseButton')),
      warnIfMissed: false,
    );
    await tester.pump();
    read.complete();
    await tester.pumpAndSettle();

    expect(purchases.impactQueries, hasLength(1));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(inDialog('Delete'));
    await tester.pumpAndSettle();
    expect(purchases.calls.where((c) => c == 'delete:e1'), hasLength(1));
  });

  testWidgets('Delete is usable again after Cancel', (tester) async {
    purchases.tabIds['e1'] = 't1';
    purchases.impactFor = (q) => const PurchaseChangeImpact(
      paidOnIt: 2,
      movesTo: [],
      becomesCredit: 2,
      currency: 'OMR',
    );
    await pumpDetails(tester);

    await tester.tap(find.byKey(const Key('deleteExpenseButton')));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();

    final button = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('deleteExpenseButton')),
    );
    expect(button.onPressed, isNotNull);
  });
}
