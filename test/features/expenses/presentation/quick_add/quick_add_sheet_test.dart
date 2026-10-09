import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_bottom_sheet.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/quick_add/quick_add_sheet.dart';

import '../expense_test_fakes.dart';

final _now = DateTime(2026, 10, 8, 14, 30);

void main() {
  late MemoryExpenseRepository expenses;
  late StubBudgetRepository budgets;

  setUp(() {
    QuickAddSheet.clock = () => _now;
    expenses = MemoryExpenseRepository();
    budgets = StubBudgetRepository([
      testBudget(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 31)),
    ]);
  });
  tearDown(() => QuickAddSheet.clock = DateTime.now);

  ExpenseEntity spent(String categoryId, int day) => ExpenseEntity(
    id: 'seed_${categoryId}_$day',
    budgetId: 'personal',
    amount: 100,
    categoryId: categoryId,
    date: DateTime(2026, 10, day),
    time: DateTime(2026, 10, day, 9),
    createdAt: DateTime(2026, 10, day),
    updatedAt: DateTime(2026, 10, day),
  );

  /// Opens the sheet from a button, as the app does, so closing it and the
  /// value it returns can be checked. Returns the route it asked for.
  Future<List<String?>> open(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <String?>[];
    final bloc = memoryExpenseBloc(expenses, budgets);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    results.add(
                      await AppBottomSheet.show<String>(
                        context: context,
                        builder: (_) => BlocProvider<ExpenseBloc>.value(
                          value: bloc,
                          child: const QuickAddSheet(),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> typeAmount(WidgetTester tester, String keys) async {
    for (final k in keys.split('')) {
      final key = k == '.' ? 'amountPad_decimal' : 'amountPad_$k';
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }
  }

  Future<void> tapAdd(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('quickAddSave')));
    await tester.tap(find.byKey(const Key('quickAddSave')));
    await tester.pumpAndSettle();
  }

  testWidgets('adds an expense to the active budget for today in a few taps', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('To Personal · until 31 Oct'), findsOneWidget);

    await typeAmount(tester, '250.5');
    await tester.tap(find.byKey(const Key('quickCategory_grocery')));
    await tester.pump();
    expect(find.text('Add ₹250.50'), findsOneWidget);
    await tapAdd(tester);

    expect(expenses.store, hasLength(1));
    final saved = expenses.store.values.single;
    expect(saved.budgetId, 'personal');
    expect(saved.amount, 250.5);
    expect(saved.categoryId, 'grocery');
    expect(saved.date, DateTime(2026, 10, 8));
    expect(saved.time, DateTime(2026, 10, 8, 14, 30));
    // Quiet success: the sheet closes and a short note confirms it.
    expect(find.byType(QuickAddSheet), findsNothing);
    expect(find.text('Expense added'), findsOneWidget);
  });

  testWidgets('checks only when Add is tapped, then says what is missing', (
    tester,
  ) async {
    await open(tester);
    // Nothing is flagged before trying to add.
    expect(find.text('Enter an amount.'), findsNothing);
    expect(find.text('Choose a category.'), findsNothing);

    await tapAdd(tester);
    expect(find.text('Enter an amount.'), findsOneWidget);
    expect(find.text('Choose a category.'), findsOneWidget);
    expect(expenses.store, isEmpty);

    // Fixing a field clears its message without re-checking the rest.
    await typeAmount(tester, '5');
    expect(find.text('Enter an amount.'), findsNothing);
    expect(find.text('Choose a category.'), findsOneWidget);
  });

  testWidgets('offers the most used categories first', (tester) async {
    for (final s in [
      spent('fuel', 2),
      spent('fuel', 3),
      spent('fuel', 4),
      spent('travel', 5),
      spent('travel', 6),
      spent('food', 7),
    ]) {
      expenses.store[s.id] = s;
    }
    await open(tester);

    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((c) => (c.key! as ValueKey<String>).value)
        .where((k) => k.startsWith('quickCategory_'))
        .toList();
    expect(chips, [
      'quickCategory_fuel',
      'quickCategory_travel',
      'quickCategory_food',
      'quickCategory_grocery',
      'quickCategory_shopping',
    ]);
  });

  testWidgets('a category from the full list joins the shortcuts', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('quickCategory_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('allCategory_health')));
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('quickCategory_health')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('yesterday outside the budget period is refused with the '
      'period named', (tester) async {
    budgets.budgets['personal'] = testBudget(
      start: DateTime(2026, 10, 8),
      end: DateTime(2026, 11, 7),
    );
    await open(tester);
    await typeAmount(tester, '90');
    await tester.tap(find.byKey(const Key('quickCategory_food')));
    await tester.tap(find.byKey(const Key('quickDate_yesterday')));
    await tester.pump();
    await tapAdd(tester);

    expect(
      find.text('Outside the Personal budget period (8 Oct – 7 Nov).'),
      findsOneWidget,
    );
    expect(expenses.store, isEmpty);
  });

  testWidgets('without a budget it says so and cannot add', (tester) async {
    budgets.activeId = null;
    await open(tester);

    expect(
      find.text('Create a budget before adding expenses.'),
      findsOneWidget,
    );
    final add = tester.widget<FilledButton>(
      find.byKey(const Key('quickAddSave')),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('"More details" hands what was entered to the full form', (
    tester,
  ) async {
    final results = await open(tester);
    await typeAmount(tester, '42');
    await tester.tap(find.byKey(const Key('quickCategory_fuel')));
    await tester.tap(find.byKey(const Key('quickDate_yesterday')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('quickAddMoreDetails')));
    await tester.tap(find.byKey(const Key('quickAddMoreDetails')));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddSheet), findsNothing);
    final uri = Uri.parse(results.single!);
    expect(uri.path, '/app/expenses/add');
    expect(uri.queryParameters, {
      'amount': '42',
      'category': 'fuel',
      'date': '2026-10-07',
      'budget': 'personal',
    });
  });

  testWidgets('an OMR budget takes amounts to the fils', (tester) async {
    budgets.budgets['personal'] = testBudget(
      currency: 'OMR',
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
    );
    await open(tester);
    await typeAmount(tester, '7.1259');
    await tester.tap(find.byKey(const Key('quickCategory_food')));
    await tapAdd(tester);

    expect(expenses.store.values.single.amount, 7.125);
  });

  testWidgets('a currency without minor units has no decimal key', (
    tester,
  ) async {
    budgets.budgets['personal'] = testBudget(
      currency: 'JPY',
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
    );
    await open(tester);
    expect(find.byKey(const Key('amountPad_decimal')), findsNothing);
    expect(find.byKey(const Key('amountPad_0')), findsOneWidget);
  });

  testWidgets('a failed save keeps the sheet open and says so', (tester) async {
    expenses.failWrites = 'disk full';
    await open(tester);
    await typeAmount(tester, '10');
    await tester.tap(find.byKey(const Key('quickCategory_food')));
    await tapAdd(tester);

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(find.text("Couldn't save the expense. Try again."), findsOneWidget);
    expect(find.textContaining('disk full'), findsNothing);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
      await open(tester, size: Size(width, 700), textScale: 2);
      expect(tester.takeException(), isNull);
      await typeAmount(tester, '1234567');
      expect(tester.takeException(), isNull);
    });
  }
}
