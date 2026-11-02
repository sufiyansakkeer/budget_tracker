import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/presentation/pages/expense_form_screen.dart';
import 'package:monivo/features/pay_later/domain/entities/purchase_change_impact.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tabs_usecase.dart';

import '../expense_test_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../../helpers/pay_later_fixtures.dart';

/// Pay later in the Add/Edit Expense form (spec §2 decisions 7-10, §5, §7).
void main() {
  late MemoryExpenseRepository expenses;
  late StubBudgetRepository budgets;
  late FakeTabPurchaseUseCase purchases;
  late FakeGetTabsUseCase getTabs;
  late List<Uri> newTabRequests;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final cafeteria = payLaterTab('t1', name: 'Cafeteria');
  final deli = payLaterTab('t2', name: 'Deli', currency: 'USD');
  final oldShop = payLaterTab(
    't3',
    name: 'Old shop',
  ).copyWith(isArchived: true);

  ExpenseEntity meal({
    String id = 'e1',
    double amount = 3.5,
    String budgetId = 'muscat',
    String? billId,
  }) => ExpenseEntity(
    id: id,
    budgetId: budgetId,
    amount: amount,
    categoryId: 'food',
    note: 'Dinner',
    date: today,
    time: today.add(const Duration(hours: 12)),
    billId: billId,
    createdAt: today,
    updatedAt: today,
  );

  final lunch = ExpenseEntity(
    id: 'e0',
    budgetId: 'muscat',
    amount: 2,
    categoryId: 'food',
    note: 'Lunch',
    date: DateTime(2026, 11, 3),
    time: DateTime(2026, 11, 3, 13),
    createdAt: DateTime(2026, 11, 3),
    updatedAt: DateTime(2026, 11, 3),
  );

  setUp(() async {
    await getIt.reset();
    expenses = MemoryExpenseRepository();
    budgets = StubBudgetRepository([
      testBudget(
        id: 'muscat',
        name: 'Muscat',
        currency: 'OMR',
        start: today.subtract(const Duration(days: 20)),
        end: today.add(const Duration(days: 10)),
      ),
      testBudget(
        id: 'trip',
        name: 'Trip',
        currency: 'USD',
        start: today.subtract(const Duration(days: 20)),
        end: today.add(const Duration(days: 10)),
      ),
    ])..activeId = 'muscat';
    purchases = FakeTabPurchaseUseCase();
    getTabs = FakeGetTabsUseCase();
    newTabRequests = [];
    getIt
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(
          repository: budgets,
          reconcileTabs: FakeReconcileTabUseCase(),
        ),
      )
      ..registerSingleton<GetTabsUseCase>(getTabs);
  });
  tearDown(() => getIt.reset());

  Future<void> pumpForm(
    WidgetTester tester, {
    String? expenseId,
    String? copyFromId,
    ExpensePrefill? prefill,
  }) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = memoryExpenseBloc(expenses, budgets, tabPurchases: purchases);
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
          builder: (_, _) => BlocProvider.value(
            value: bloc,
            child: ExpenseFormScreen(
              expenseId: expenseId,
              copyFromId: copyFromId,
              prefill: prefill,
            ),
          ),
        ),
        // Stands in for the tab form: creates "Campus cafe" and pops its id.
        GoRoute(
          path: '/app/pay-later/new',
          builder: (context, state) {
            newTabRequests.add(state.uri);
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        getTabs.tabs.add(
                          payLaterTab('t9', name: 'Campus cafe'),
                        );
                        context.pop('t9');
                      },
                      child: const Text('Create tab'),
                    ),
                    // The tab form lets the currency change from the one
                    // the expense form asked for.
                    TextButton(
                      onPressed: () {
                        getTabs.tabs.add(
                          payLaterTab('t8', name: 'Grocer', currency: 'USD'),
                        );
                        context.pop('t8');
                      },
                      child: const Text('Create USD tab'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
  }

  Finder amountField() => find.byType(TextFormField).first;

  SegmentedButton<bool> paidChoice(WidgetTester tester) =>
      tester.widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>));

  ChoiceChip tabChip(WidgetTester tester, String id) =>
      tester.widget<ChoiceChip>(find.byKey(Key('tab_$id')));

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();
  }

  Future<void> choosePayLater(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('paidLaterSegment')));
    await tester.pumpAndSettle();
  }

  Future<void> pickBudget(WidgetTester tester, String name) async {
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(name).last);
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  PurchaseChangeImpact impact({
    double paid = 2,
    List<(ExpenseEntity, double)> movesTo = const [],
    double credit = 0,
  }) => PurchaseChangeImpact(
    paidOnIt: paid,
    movesTo: movesTo,
    becomesCredit: credit,
    currency: 'OMR',
  );

  test('the add route reads the preselected tab', () {
    final prefill = ExpensePrefill.fromQuery({'tab': 't1'});
    expect(prefill.tabId, 't1');
    expect(prefill.isEmpty, isFalse);
  });

  testWidgets('Now is selected by default and saves a plain ExpenseCreate', (
    tester,
  ) async {
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester);

    expect(paidChoice(tester).selected, {false});
    expect(find.byKey(const Key('tabSelector')), findsNothing);

    await tester.enterText(amountField(), '2.5');
    await tester.tap(find.byKey(const Key('category_food')));
    await tester.pump();
    await tapSave(tester);

    expect(expenses.store.values.single.amount, 2.5);
    // Today's exact path: no Pay later read or write at all.
    expect(purchases.calls, isEmpty);
    expect(getTabs.calls, 0);
  });

  testWidgets('Pay later shows compatible tabs only', (tester) async {
    getTabs.tabs.addAll([cafeteria, deli, oldShop]);
    await pumpForm(tester);

    await choosePayLater(tester);
    expect(find.byKey(const Key('tabSelector')), findsOneWidget);
    expect(tabChip(tester, 't1').onSelected, isNotNull);
    // Another currency is listed, disabled, with the reason.
    expect(tabChip(tester, 't2').onSelected, isNull);
    expect(find.textContaining('In USD'), findsOneWidget);
    // Archived tabs take no new purchases.
    expect(find.byKey(const Key('tab_t3')), findsNothing);

    await tester.tap(find.byKey(const Key('tab_t1')));
    await tester.enterText(amountField(), '1.25');
    await tester.tap(find.byKey(const Key('category_food')));
    await tester.pump();
    await tapSave(tester);

    expect(purchases.calls.single, startsWith('create:'));
    expect(purchases.calls.single, endsWith(':t1'));
    expect(find.byType(ExpenseFormScreen), findsNothing);
  });

  testWidgets('Pay later with no tab chosen asks for one', (tester) async {
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester);
    await choosePayLater(tester);

    await tester.enterText(amountField(), '1');
    await tester.tap(find.byKey(const Key('category_food')));
    await tester.pump();
    await tapSave(tester);

    expect(find.text('Choose a tab for this purchase.'), findsOneWidget);
    expect(purchases.calls, isEmpty);
    expect(expenses.store, isEmpty);
  });

  testWidgets('create first tab returns with it selected and the amount kept', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(amountField(), '3.5');
    await tester.enterText(find.byType(TextFormField).at(1), 'Shawarma');
    await tester.pump();

    await choosePayLater(tester);
    expect(find.byKey(const Key('tab_t1')), findsNothing);
    await tester.tap(find.byKey(const Key('createFirstTabButton')));
    await tester.pumpAndSettle();

    // The new tab starts in the selected budget's currency.
    expect(newTabRequests.single.queryParameters['currency'], 'OMR');
    await tester.tap(find.text('Create tab'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(tabChip(tester, 't9').selected, isTrue);
    expect(find.text('3.5'), findsOneWidget);
    expect(find.text('Shawarma'), findsOneWidget);
    expect(paidChoice(tester).selected, {true});
  });

  testWidgets('a tab created in another currency comes back selected, '
      'says why it does not fit, and blocks the save', (tester) async {
    await pumpForm(tester);
    await tester.enterText(amountField(), '3.5');
    await tester.tap(find.byKey(const Key('category_food')));
    await tester.pump();

    await choosePayLater(tester);
    await tester.tap(find.byKey(const Key('createFirstTabButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create USD tab'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(tabChip(tester, 't8').selected, isTrue);
    final error = find.byKey(const Key('tabCurrencyError'));
    expect(error, findsOneWidget);
    expect(
      find.descendant(of: error, matching: find.textContaining('USD')),
      findsWidgets,
    );

    await tapSave(tester);
    expect(purchases.calls, isEmpty);
    expect(expenses.store, isEmpty);
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(find.text('3.5'), findsOneWidget);
  });

  testWidgets('opened from a tab, Pay later and its default category are '
      'preselected', (tester) async {
    getTabs.tabs.add(cafeteria.copyWith(defaultCategoryId: 'fuel'));
    await pumpForm(tester, prefill: ExpensePrefill.fromQuery({'tab': 't1'}));

    expect(paidChoice(tester).selected, {true});
    expect(tabChip(tester, 't1').selected, isTrue);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('category_fuel')))
          .selected,
      isTrue,
    );
  });

  testWidgets("an archived default category isn't preselected", (tester) async {
    expenses.categories = [
      for (final c in defaultCategories)
        c.id == 'fuel' ? c.copyWith(isArchived: true) : c,
    ];
    getTabs.tabs.add(cafeteria.copyWith(defaultCategoryId: 'fuel'));
    await pumpForm(tester, prefill: ExpensePrefill.fromQuery({'tab': 't1'}));

    expect(tabChip(tester, 't1').selected, isTrue);
    expect(find.byKey(const Key('category_fuel')), findsNothing);
    for (final chip in tester.widgetList<ChoiceChip>(
      find.byWidgetPredicate(
        (w) =>
            w is ChoiceChip &&
            (w.key as ValueKey<String>?)?.value.startsWith('category_') == true,
      ),
    )) {
      expect(chip.selected, isFalse);
    }
  });

  testWidgets('tab purchase cannot move to another currency', (tester) async {
    expenses.store['e1'] = meal();
    purchases.tabIds['e1'] = 't1';
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester, expenseId: 'e1');

    expect(paidChoice(tester).selected, {true});
    expect(tabChip(tester, 't1').selected, isTrue);

    await pickBudget(tester, 'Trip');
    final error = find.byKey(const Key('tabCurrencyError'));
    expect(error, findsOneWidget);
    expect(
      find.descendant(of: error, matching: find.textContaining('OMR')),
      findsOneWidget,
    );

    await tapSave(tester);
    // Blocked, not warned: no "Count this in USD?" question, no save.
    expect(find.text('Count this in USD?'), findsNothing);
    expect(purchases.calls.where((c) => c.startsWith('update:')), isEmpty);
    expect(expenses.store['e1']!.budgetId, 'muscat');
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
  });

  testWidgets('a new tab purchase in another currency is blocked too', (
    tester,
  ) async {
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester);
    await choosePayLater(tester);
    await tester.tap(find.byKey(const Key('tab_t1')));
    await tester.enterText(amountField(), '4');
    await tester.tap(find.byKey(const Key('category_food')));
    await tester.pump();
    await pickBudget(tester, 'Trip');

    await tapSave(tester);
    expect(find.byKey(const Key('tabCurrencyError')), findsOneWidget);
    expect(purchases.calls, isEmpty);
  });

  testWidgets('editing a paid purchase down shows the impact dialog', (
    tester,
  ) async {
    expenses.store['e1'] = meal();
    purchases.tabIds['e1'] = 't1';
    purchases.impactFor = (q) => impact(movesTo: [(lunch, 2.0)]);
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester, expenseId: 'e1');

    await tester.enterText(amountField(), '1.5');
    await tapSave(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining('already paid on this purchase'),
      findsOneWidget,
    );
    expect(find.textContaining('Lunch'), findsOneWidget);
    final query = purchases.impactQueries.single;
    expect(query.expenseId, 'e1');
    expect(query.newAmount, 1.5);
    expect(query.newTabId, 't1');
    expect(query.deleting, isFalse);

    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();
    expect(purchases.calls.where((c) => c.startsWith('update:')), isEmpty);
    expect(find.byType(ExpenseFormScreen), findsOneWidget);

    await tapSave(tester);
    await tester.tap(inDialog('Save'));
    await tester.pumpAndSettle();
    expect(purchases.calls, contains('update:e1:t1'));
    expect(find.byType(ExpenseFormScreen), findsNothing);
  });

  testWidgets('raising the amount of a paid purchase saves without asking', (
    tester,
  ) async {
    expenses.store['e1'] = meal();
    purchases.tabIds['e1'] = 't1';
    purchases.impactFor = (q) => impact(paid: 0);
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester, expenseId: 'e1');

    await tester.enterText(amountField(), '5');
    await tapSave(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(purchases.calls, contains('update:e1:t1'));
  });

  testWidgets('turning Pay later off on a paid purchase says the money stays '
      'as credit', (tester) async {
    expenses.store['e1'] = meal();
    purchases.tabIds['e1'] = 't1';
    purchases.impactFor = (q) => impact(credit: 2);
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester, expenseId: 'e1');

    await tester.tap(find.byKey(const Key('paidNowSegment')));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(purchases.impactQueries.single.newTabId, isNull);
    expect(find.textContaining('stay on the tab as credit'), findsOneWidget);
    await tester.tap(inDialog('Save'));
    await tester.pumpAndSettle();
    expect(purchases.calls, contains('update:e1:null'));
  });

  testWidgets("a payments check that fails doesn't save", (tester) async {
    expenses.store['e1'] = meal();
    purchases.tabIds['e1'] = 't1';
    purchases.impactError = Exception('database is locked');
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester, expenseId: 'e1');

    await tester.enterText(amountField(), '1');
    await tapSave(tester);

    expect(
      find.text("Couldn't check this purchase's payments. Try again."),
      findsOneWidget,
    );
    expect(purchases.calls.where((c) => c.startsWith('update:')), isEmpty);
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
  });

  testWidgets("when the tab link can't be read, saving an edit is refused "
      'with neutral copy (M5)', (tester) async {
    expenses.store['e1'] = meal();
    purchases.tabIdForError = Exception('database is locked');
    await pumpForm(tester, expenseId: 'e1');

    await tester.enterText(amountField(), '4.25');
    await tapSave(tester);

    expect(find.text("Couldn't save your changes. Try again."), findsOneWidget);
    expect(
      find.text("Couldn't check this purchase's payments. Try again."),
      findsNothing,
    );
    expect(expenses.store['e1']!.amount, 3.5);
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
  });

  testWidgets('editing a plain expense with Now saves exactly as before', (
    tester,
  ) async {
    expenses.store['e1'] = meal();
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester, expenseId: 'e1');

    expect(paidChoice(tester).selected, {false});
    await tester.enterText(amountField(), '4.25');
    await tapSave(tester);

    expect(expenses.store['e1']!.amount, 4.25);
    expect(purchases.calls, ['tabIdFor:e1']);
    expect(getTabs.calls, 0);
  });

  testWidgets("a bill payment can't go on a tab", (tester) async {
    expenses.store['e1'] = meal(billId: 'rent');
    getTabs.tabs.add(cafeteria);
    await pumpForm(tester, expenseId: 'e1');

    expect(paidChoice(tester).segments.last.enabled, isFalse);
    expect(find.text("Bill payments can't go on a tab."), findsOneWidget);
  });

  group('duplicate (I2)', () {
    testWidgets('duplicating a tab purchase keeps it on its tab', (
      tester,
    ) async {
      expenses.store['e1'] = meal();
      purchases.tabIds['e1'] = 't1';
      getTabs.tabs.add(cafeteria);
      await pumpForm(tester, copyFromId: 'e1');

      expect(paidChoice(tester).selected, {true});
      expect(tabChip(tester, 't1').selected, isTrue);

      // Untouched, it is not "unsaved changes".
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this expense?'), findsNothing);
      expect(find.byType(ExpenseFormScreen), findsNothing);
    });

    testWidgets('the copy saves on the same tab', (tester) async {
      expenses.store['e1'] = meal();
      purchases.tabIds['e1'] = 't1';
      getTabs.tabs.add(cafeteria);
      await pumpForm(tester, copyFromId: 'e1');

      await tapSave(tester);

      expect(purchases.calls.where((c) => c.startsWith('create:')), [
        matches(RegExp(r'^create:(?!e1:).+:t1$')),
      ]);
    });

    testWidgets('an archived tab is not chosen: the copy is Now', (
      tester,
    ) async {
      expenses.store['e1'] = meal();
      purchases.tabIds['e1'] = 't3';
      getTabs.tabs.addAll([cafeteria, oldShop]);
      await pumpForm(tester, copyFromId: 'e1');

      expect(paidChoice(tester).selected, {false});
    });

    testWidgets('a tab in another currency than the budget is not chosen', (
      tester,
    ) async {
      expenses.store['e1'] = meal();
      purchases.tabIds['e1'] = 't2';
      getTabs.tabs.addAll([cafeteria, deli]);
      await pumpForm(tester, copyFromId: 'e1');

      expect(paidChoice(tester).selected, {false});
    });

    testWidgets('a plain expense, or an unreadable link, copies as Now', (
      tester,
    ) async {
      expenses.store['e1'] = meal();
      getTabs.tabs.add(cafeteria);
      await pumpForm(tester, copyFromId: 'e1');
      expect(paidChoice(tester).selected, {false});
      expect(getTabs.calls, 0);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      purchases.tabIdForError = Exception('database is locked');
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(paidChoice(tester).selected, {false});
    });
  });

  testWidgets('when the tab link cannot be read on open, back still asks '
      'before dropping typed edits (T9)', (tester) async {
    expenses.store['e1'] = meal();
    purchases.tabIdForError = Exception('database is locked');
    await pumpForm(tester, expenseId: 'e1');

    await tester.enterText(amountField(), '9');
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('when the tab link cannot be read, an untouched edit closes '
      'without asking', (tester) async {
    expenses.store['e1'] = meal();
    purchases.tabIdForError = Exception('database is locked');
    await pumpForm(tester, expenseId: 'e1');

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(ExpenseFormScreen), findsNothing);
  });
}
