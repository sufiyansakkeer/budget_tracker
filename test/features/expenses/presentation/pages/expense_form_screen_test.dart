import 'dart:async';

import 'package:monivo/core/dates/calendar_dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_amount_field.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/pages/expense_form_screen.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_undo.dart';

import '../expense_test_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import 'package:monivo/core/constants/app_copy.dart';

/// Saves only once [gate] completes, so a test can act mid-save.
class _GatedExpenseRepository extends MemoryExpenseRepository {
  final gate = Completer<void>();

  @override
  Future<void> createExpense(ExpenseEntity expense) async {
    await gate.future;
    return super.createExpense(expense);
  }
}

/// Lists budgets only once [gate] completes.
class _GatedBudgetRepository extends StubBudgetRepository {
  final gate = Completer<void>();

  _GatedBudgetRepository(super.initial);

  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async {
    await gate.future;
    return super.getAllBudgets(options: options);
  }
}

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
      ManageBudgetUseCase(
        repository: budgets,
        reconcileTabs: FakeReconcileTabUseCase(),
      ),
    );
  });
  tearDown(() => getIt.reset());

  Future<ExpenseBloc> pumpForm(
    WidgetTester tester, {
    String? expenseId,
    String? copyFromId,
    ExpensePrefill? prefill,
    bool settle = true,
    GetSafeToSpendUseCase? safeToSpend,
  }) async {
    final bloc = memoryExpenseBloc(expenses, budgets, safeToSpend: safeToSpend);
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
            child: ExpenseFormScreen(
              expenseId: expenseId,
              copyFromId: copyFromId,
              prefill: prefill,
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.tap(find.text('Home'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Placeholders shimmer until their data arrives.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
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
    final yesterday = DateTime.now().addDays(-1);
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
    expect(find.text(ValidationCopy.amountNotPositive), findsNothing);

    await tapSave(tester);
    expect(find.text(ValidationCopy.amountNotPositive), findsOneWidget);
    expect(expenses.store, isEmpty);

    // Typing again clears the message until the next save.
    await tester.enterText(amountField(), '05');
    await tester.pump();
    expect(find.text(ValidationCopy.amountNotPositive), findsNothing);
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
    expect(find.text('₹120 added'), findsOneWidget);
  });

  testWidgets('Undo on the note deletes the expense just added', (
    tester,
  ) async {
    ExpenseUndo.blocFactory = () => memoryExpenseBloc(expenses, budgets);
    addTearDown(() => ExpenseUndo.blocFactory = () => getIt<ExpenseBloc>());
    await pumpForm(tester);
    await tester.enterText(amountField(), '120');
    await tester.tap(find.byKey(const Key('category_food')));
    await tester.pump();
    await tapSave(tester);
    expect(expenses.store, hasLength(1));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(expenses.store, isEmpty);
  });

  testWidgets('closing an untouched form needs no confirmation', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsNothing);
  });

  group('with the keyboard open', () {
    testWidgets('the save button stays above it', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await pumpForm(tester);

      final save = tester.getRect(find.byKey(const Key('saveExpenseButton')));
      expect(save.bottom, lessThanOrEqualTo(800 - 300));
    });

    testWidgets('tapping outside the amount closes it (no Done key on iOS)', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.showKeyboard(amountField());
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.text('Paid'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('choosing a category closes it, from any field', (
      tester,
    ) async {
      // Tall enough that the note and the chips are both on screen.
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpForm(tester);
      await tester.showKeyboard(
        find.widgetWithText(TextField, 'Note (optional)'),
      );
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(const Key('category_food')));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
    });
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
    final note = find.widgetWithText(TextField, 'Note (optional)');
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

  group('UX-005: changing an expense to a budget in another currency', () {
    setUp(() {
      final today = DateTime.now();
      budgets.budgets['trip'] = testBudget(
        id: 'trip',
        name: 'Trip',
        currency: 'USD',
        start: DateTime(today.year, today.month, today.day - 20),
        end: DateTime(today.year, today.month, today.day + 10),
      );
      final day = DateTime(today.year, today.month, today.day);
      expenses.store['e1'] = ExpenseEntity(
        id: 'e1',
        budgetId: 'personal',
        amount: 300,
        categoryId: 'food',
        date: day,
        time: day.add(const Duration(hours: 9)),
        createdAt: day,
        updatedAt: day,
      );
    });

    Future<void> pickTrip(WidgetTester tester) async {
      // The "Paid" row pushed the picker below the first screen.
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<String>),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Trip').last);
      await tester.pumpAndSettle();
    }

    testWidgets('warns, asks before saving, and "Go back" saves nothing', (
      tester,
    ) async {
      await pumpForm(tester, expenseId: 'e1');
      expect(
        find.byKey(const ValueKey('expenseCurrencyChangeWarning')),
        findsNothing,
      );

      await pickTrip(tester);
      expect(
        find.text(
          'Trip uses USD. The amount is not converted, so enter it in USD.',
        ),
        findsOneWidget,
      );

      await tapSave(tester);
      expect(find.text('Count this in USD?'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(expenses.store['e1']!.budgetId, 'personal', reason: 'not saved');

      await tapSave(tester);
      await tester.tap(find.text('Save in USD'));
      await tester.pumpAndSettle();
      expect(expenses.store['e1']!.budgetId, 'trip');
    });

    testWidgets('the picker names each budget\'s currency when they differ', (
      tester,
    ) async {
      await pumpForm(tester, expenseId: 'e1');
      // The "Paid" row pushed the picker below the first screen.
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<String>),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.textContaining('· USD'), findsWidgets);
      expect(find.textContaining('· INR'), findsWidgets);
    });
  });

  group('OMR budget', () {
    setUp(() {
      final today = DateTime.now();
      budgets.budgets['personal'] = testBudget(
        currency: 'OMR',
        start: DateTime(today.year, today.month, today.day - 20),
        end: DateTime(today.year, today.month, today.day + 10),
      );
    });

    testWidgets('saves an amount to the fils (review: it stopped at two '
        'decimal places)', (tester) async {
      await pumpForm(tester);
      await tester.enterText(amountField(), '7.1259');
      await tester.pump();
      // The field stops at three decimals.
      expect(find.text('7.125'), findsOneWidget);
      await tester.tap(find.byKey(const Key('category_food')));
      await tester.pump();
      await tapSave(tester);

      expect(expenses.store.values.single.amount, 7.125);
    });

    testWidgets('editing shows every saved decimal, never 7.13', (
      tester,
    ) async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      expenses.store['omr'] = ExpenseEntity(
        id: 'omr',
        budgetId: 'personal',
        amount: 7.125,
        categoryId: 'food',
        date: day,
        time: day.add(const Duration(hours: 9)),
        createdAt: day,
        updatedAt: day,
      );
      await pumpForm(tester, expenseId: 'omr');

      expect(find.text('7.125'), findsOneWidget);
      expect(find.text('7.13'), findsNothing);
    });

    testWidgets('an expense in an archived budget saves with that budget\'s '
        'decimals', (tester) async {
      // The form listed only unarchived budgets, so the expense's own budget
      // was missing: OMR 7.125 was checked against two decimals and refused.
      final today = DateTime.now();
      budgets.budgets['personal'] = testBudget(
        currency: 'OMR',
        start: DateTime(today.year, today.month, today.day - 20),
        end: DateTime(today.year, today.month, today.day + 10),
        archived: true,
      );
      final day = DateTime(today.year, today.month, today.day);
      expenses.store['omr'] = ExpenseEntity(
        id: 'omr',
        budgetId: 'personal',
        amount: 7.125,
        categoryId: 'food',
        date: day,
        time: day.add(const Duration(hours: 9)),
        createdAt: day,
        updatedAt: day,
      );
      await pumpForm(tester, expenseId: 'omr');

      await tapSave(tester);

      expect(find.textContaining('decimal places'), findsNothing);
      expect(expenses.store['omr']!.amount, 7.125);
      expect(expenses.store['omr']!.budgetId, 'personal');
    });
  });

  group('P3', () {
    Finder listScrollable() => find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;

    Future<void> scrollTo(WidgetTester tester, Finder finder) =>
        tester.scrollUntilVisible(finder, 200, scrollable: listScrollable());

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    void useBudgets(StubBudgetRepository repo) {
      getIt.unregister<ManageBudgetUseCase>();
      getIt.registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(
          repository: repo,
          reconcileTabs: FakeReconcileTabUseCase(),
        ),
      );
    }

    // UX-077: a tag typed but not added with + was dropped on save.
    testWidgets('a tag still being typed is saved with the expense', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(amountField(), '80');
      await tester.tap(find.byKey(const Key('category_food')));
      await tester.pump();
      final tags = find.widgetWithText(TextField, 'Tags (optional)');
      await scrollTo(tester, tags);
      await tester.enterText(tags, 'Office');
      await tester.pump();

      await tapSave(tester);

      expect(expenses.store.values.single.tags, ['Office']);
    });

    // UX-077: a new expense moved to another budget closed without asking.
    testWidgets('changing only the budget of a new expense asks before '
        'closing', (tester) async {
      final today = DateTime.now();
      budgets.budgets['trip'] = testBudget(
        id: 'trip',
        name: 'Trip',
        start: DateTime(today.year, today.month, today.day - 20),
        end: DateTime(today.year, today.month, today.day + 10),
      );
      await pumpForm(tester);
      final picker = find.byType(DropdownButtonFormField<String>);
      await scrollTo(tester, picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Trip').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this expense?'), findsOneWidget);
    });

    // UX-078: the picker offered ten years back, whatever the budget.
    testWidgets('the date picker offers only the budget\'s days up to today', (
      tester,
    ) async {
      tall(tester);
      await pumpForm(tester);
      final budget = budgets.budgets['personal']!;
      await tester.ensureVisible(find.byKey(const Key('expenseDatePicker')));
      await tester.tap(find.byKey(const Key('expenseDatePicker')));
      await tester.pumpAndSettle();

      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      final now = DateTime.now();
      expect(
        dialog.firstDate,
        DateTime(
          budget.startDate.year,
          budget.startDate.month,
          budget.startDate.day,
        ),
      );
      expect(dialog.lastDate, DateTime(now.year, now.month, now.day));
    });

    // UX-079: categories that couldn't be read left a shimmer forever.
    testWidgets('categories that cannot be read say so, and Retry loads them', (
      tester,
    ) async {
      expenses.failCategories = 'disk busy';
      await pumpForm(tester);

      expect(find.text("Couldn't load categories."), findsOneWidget);
      expect(find.text('Loading categories'), findsNothing);

      expenses.failCategories = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category_food')), findsOneWidget);
      expect(find.text("Couldn't load categories."), findsNothing);
    });

    // UX-080: Back during a save offered to discard while it still saved.
    testWidgets('Back does nothing while a save runs', (tester) async {
      final gated = _GatedExpenseRepository();
      expenses = gated;
      await pumpForm(tester);
      addTearDown(() {
        if (!gated.gate.isCompleted) gated.gate.complete();
      });
      await tester.enterText(amountField(), '60');
      await tester.tap(find.byKey(const Key('category_food')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('saveExpenseButton')));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Discard this expense?'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(find.text('Discard this expense?'), findsNothing);
      expect(find.byType(ExpenseFormScreen), findsOneWidget);

      gated.gate.complete();
      await tester.pumpAndSettle();
      expect(expenses.store, hasLength(1));
      expect(find.byType(ExpenseFormScreen), findsNothing);
    });

    // UX-081: the section titles weren't headings.
    testWidgets('Category and Details are headings', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpForm(tester);
      expect(
        tester.getSemantics(find.text('Category')),
        containsSemantics(isHeader: true),
      );
      await scrollTo(tester, find.text('Details'));
      expect(
        tester.getSemantics(find.text('Details')),
        containsSemantics(isHeader: true),
      );
      handle.dispose();
    });

    // UX-082: ₹ showed until the budget's currency was known.
    testWidgets('no currency symbol shows before the budget is known', (
      tester,
    ) async {
      final today = DateTime.now();
      final gated = _GatedBudgetRepository([
        testBudget(
          currency: 'OMR',
          start: DateTime(today.year, today.month, today.day - 20),
          end: DateTime(today.year, today.month, today.day + 10),
        ),
      ]);
      useBudgets(gated);
      await pumpForm(tester, settle: false);
      // Runs before the bloc closes, so a failed check never hangs it.
      addTearDown(() {
        if (!gated.gate.isCompleted) gated.gate.complete();
      });

      String? prefix() => tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(AppAmountField),
              matching: find.byType(TextField),
            ),
          )
          .decoration!
          .prefixText;
      expect(
        tester.widget<AppAmountField>(find.byType(AppAmountField)).currency,
        isNull,
      );
      expect(prefix(), isNull);

      gated.gate.complete();
      await tester.pumpAndSettle();
      expect(prefix(), '${CurrencyFormatter.symbolFor('OMR')} ');
    });

    // UX-084: Budget sat under "Details" with the optional fields.
    testWidgets('Budget sits with the date; the details say they are '
        'optional', (tester) async {
      tall(tester);
      await pumpForm(tester);

      final budgetTop = tester
          .getTopLeft(find.byType(DropdownButtonFormField<String>))
          .dy;
      expect(budgetTop, lessThan(tester.getTopLeft(find.text('Details')).dy));
      expect(
        budgetTop,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('expenseDatePicker'))).dy,
        ),
      );
      expect(find.widgetWithText(TextField, 'Note (optional)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Tags (optional)'), findsOneWidget);
      expect(find.text('Receipt (optional)'), findsOneWidget);
    });

    // UX-084: a duplicate kept a budget that had ended, then failed on save.
    testWidgets('a duplicate of an expense in an ended budget starts in the '
        'active one', (tester) async {
      final today = DateTime.now();
      budgets.budgets['old'] = testBudget(
        id: 'old',
        name: 'Old',
        start: DateTime(today.year, today.month, today.day - 60),
        end: DateTime(today.year, today.month, today.day - 30),
      );
      final day = DateTime(today.year, today.month, today.day - 40);
      expenses.store['src'] = ExpenseEntity(
        id: 'src',
        budgetId: 'old',
        amount: 90,
        categoryId: 'food',
        date: day,
        time: day.add(const Duration(hours: 9)),
        createdAt: day,
        updatedAt: day,
      );
      tall(tester);
      await pumpForm(tester, copyFromId: 'src');

      final picker = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(picker.value, 'personal');

      // That choice is where the duplicate starts, not an edit to ask about.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseFormScreen), findsNothing);
    });

    testWidgets('a duplicate whose budget still covers today keeps it', (
      tester,
    ) async {
      final today = DateTime.now();
      budgets.budgets['trip'] = testBudget(
        id: 'trip',
        name: 'Trip',
        start: DateTime(today.year, today.month, today.day - 5),
        end: DateTime(today.year, today.month, today.day + 5),
      );
      final day = DateTime(today.year, today.month, today.day);
      expenses.store['src'] = ExpenseEntity(
        id: 'src',
        budgetId: 'trip',
        amount: 90,
        categoryId: 'food',
        date: day,
        time: day.add(const Duration(hours: 9)),
        createdAt: day,
        updatedAt: day,
      );
      tall(tester);
      await pumpForm(tester, copyFromId: 'src');

      final picker = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(picker.value, 'trip');
    });
  });

  group('what it does to today, before saving (blueprint)', () {
    testWidgets('a new expense today shows left today as it is typed', (
      tester,
    ) async {
      await pumpForm(tester, safeToSpend: _TodayInput());
      expect(find.text('Left today'), findsOneWidget);

      await tester.enterText(amountField(), '40');
      await tester.pump();
      expect(find.text('₹60'), findsOneWidget);
    });

    testWidgets('editing an expense shows nothing', (tester) async {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      expenses.store['e1'] = ExpenseEntity(
        id: 'e1',
        budgetId: 'personal',
        amount: 30,
        categoryId: 'food',
        date: day,
        time: day,
        createdAt: day,
        updatedAt: day,
      );
      await pumpForm(tester, expenseId: 'e1', safeToSpend: _TodayInput());
      expect(find.byKey(const Key('todayImpact')), findsNothing);
    });
  });
}

/// 1,100 over the 11 days left of the test budget (it ends in 10 days):
/// 100 a day, nothing spent.
class _TodayInput implements GetSafeToSpendUseCase {
  @override
  Future<SafeToSpendInput?> inputFor({
    required String budgetId,
    DateTime? referenceDate,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return SafeToSpendInput(
      budgetId: budgetId,
      budgetName: 'Personal',
      currency: 'INR',
      startDate: today.subtract(const Duration(days: 20)),
      endDate: DateTime(today.year, today.month, today.day + 10),
      today: today,
      budgetAmount: 1100,
      periodSpent: 0,
      todaySpent: 0,
      commitments: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
