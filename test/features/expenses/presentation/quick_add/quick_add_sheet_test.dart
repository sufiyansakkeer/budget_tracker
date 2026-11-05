import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/widgets/app_bottom_sheet.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/presentation/start_next_period.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/quick_add/quick_add_sheet.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_undo.dart';

import '../expense_test_fakes.dart';

final _now = DateTime(2026, 10, 8, 14, 30);

/// Today's Safe Spending for the Personal budget as the engine works it out
/// from [periodSpent] and [todaySpent], dated [_now].
class _FakeSafeToSpend implements GetSafeToSpendUseCase {
  double budgetAmount = 2400;
  double todaySpent = 0;
  final List<String> asked = [];

  @override
  Future<BudgetResult<SafeToSpendEntity>> call({
    required String budgetId,
    DateTime? referenceDate,
  }) async {
    asked.add(budgetId);
    return BudgetSuccess(
      SafeToSpendCalculator(BudgetCalculationService()).calculate(
        SafeToSpendInput(
          budgetId: budgetId,
          budgetName: 'Personal',
          currency: 'INR',
          startDate: DateTime(2026, 10, 8),
          endDate: DateTime(2026, 10, 31),
          today: DateTime(2026, 10, 8),
          budgetAmount: budgetAmount,
          periodSpent: todaySpent,
          todaySpent: todaySpent,
          commitments: const [],
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
    GetSafeToSpendUseCase? safeToSpend,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <String?>[];
    final bloc = memoryExpenseBloc(expenses, budgets, safeToSpend: safeToSpend);
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
                        // As QuickAddSheet.show: the sheet draws its own.
                        showDragHandle: false,
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

  testWidgets('a budget that cannot be read is not reported as missing', (
    tester,
  ) async {
    budgets.failActiveReads = true;
    await open(tester);

    expect(find.text("Couldn't load"), findsOneWidget);
    expect(find.text('No budget yet'), findsNothing);
  });

  testWidgets('categories that cannot be read say so too', (tester) async {
    expenses.failCategories = 'disk busy';
    await open(tester);

    expect(find.text("Couldn't load"), findsOneWidget);
  });

  testWidgets('Try again loads the sheet once reads work', (tester) async {
    budgets.failActiveReads = true;
    await open(tester);

    budgets.failActiveReads = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load"), findsNothing);
    expect(find.text('To Personal · until 31 Oct'), findsOneWidget);
  });

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
    expect(find.text('₹250.50 added'), findsOneWidget);
  });

  group('the "added" note', () {
    late _FakeSafeToSpend safe;
    setUp(() {
      safe = _FakeSafeToSpend();
      ExpenseUndo.blocFactory = () => memoryExpenseBloc(expenses, budgets);
    });
    tearDown(() => ExpenseUndo.blocFactory = () => getIt<ExpenseBloc>());

    Future<void> add(WidgetTester tester, String amount) async {
      await open(tester, safeToSpend: safe);
      await typeAmount(tester, amount);
      await tester.tap(find.byKey(const Key('quickCategory_food')));
      await tester.pump();
      // What the engine sees once the expense is saved.
      safe.todaySpent = double.parse(amount);
      await tapAdd(tester);
    }

    testWidgets("says what is left today, from the engine", (tester) async {
      await add(tester, '40');
      expect(safe.asked, ['personal']);
      // 2400 over 24 days is 100 a day; 40 spent leaves 60.
      expect(find.text('₹40 added · ₹60 left today'), findsOneWidget);
    });

    testWidgets('or how far over today it is', (tester) async {
      await add(tester, '250');
      expect(find.text('₹250 added · over by ₹150 today'), findsOneWidget);
    });

    testWidgets('an expense on another day shows the amount only', (
      tester,
    ) async {
      budgets.budgets['personal'] = testBudget(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
      );
      await open(tester, safeToSpend: safe);
      await typeAmount(tester, '30');
      await tester.tap(find.byKey(const Key('quickCategory_food')));
      await tester.tap(find.byKey(const Key('quickDate_yesterday')));
      await tester.pump();
      await tapAdd(tester);
      expect(find.text('₹30 added'), findsOneWidget);
    });

    testWidgets('Undo deletes the expense it added', (tester) async {
      await add(tester, '40');
      expect(expenses.store, hasLength(1));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(expenses.store, isEmpty);
    });
  });

  group('leaving with something entered', () {
    testWidgets('an untouched sheet closes at once on Back', (tester) async {
      final results = await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddSheet), findsNothing);
      expect(find.text('Discard this expense?'), findsNothing);
      expect(results, [null]);
    });

    testWidgets('an untouched sheet still swipes away', (tester) async {
      await open(tester);
      await tester.fling(
        find.text('Add expense').first,
        const Offset(0, 400),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddSheet), findsNothing);
    });

    testWidgets('Back with an amount asks, as the form does', (tester) async {
      final results = await open(tester);
      await typeAmount(tester, '25');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard this expense?'), findsOneWidget);
      expect(find.text("What you entered hasn't been saved."), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddSheet), findsOneWidget);
      expect(find.text('Add ₹25'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddSheet), findsNothing);
      expect(results, [null]);
      expect(expenses.store, isEmpty);
    });

    testWidgets('a scrim tap with a category asks', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('quickCategory_food')));
      await tester.pump();

      await tester.tapAt(const Offset(200, 10));
      await tester.pumpAndSettle();
      expect(find.text('Discard this expense?'), findsOneWidget);
      expect(find.byType(QuickAddSheet), findsOneWidget);
    });

    testWidgets('a swipe down with an amount asks', (tester) async {
      await open(tester);
      await typeAmount(tester, '25');

      await tester.fling(
        find.text('Add expense').first,
        const Offset(0, 400),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Discard this expense?'), findsOneWidget);
      expect(find.byType(QuickAddSheet), findsOneWidget);
    });
  });

  group('a budget not running today', () {
    testWidgets('an ended one says so and offers the next budget', (
      tester,
    ) async {
      budgets.budgets['personal'] = testBudget(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      );
      final results = await open(tester);
      expect(find.text('Your Personal budget ended on 30 Sep'), findsOneWidget);

      await tester.tap(find.text('Start next budget'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddSheet), findsNothing);
      expect(results, [StartNextPeriod.location('personal')]);
    });

    testWidgets('"Add to Personal" picks a day in its period, then adds', (
      tester,
    ) async {
      budgets.budgets['personal'] = testBudget(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      );
      await open(tester);
      await typeAmount(tester, '12');
      await tester.tap(find.byKey(const Key('quickCategory_food')));
      await tester.tap(find.text('Add to Personal'));
      await tester.pumpAndSettle();

      // The picker stops at the budget's last day.
      expect(find.text('September 2026'), findsOneWidget);
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Your Personal budget ended on 30 Sep'), findsNothing);

      await tapAdd(tester);
      expect(expenses.store.values.single.date, DateTime(2026, 9, 15));
    });

    testWidgets('one not started yet explains why Add is off', (tester) async {
      budgets.budgets['personal'] = testBudget(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 30),
      );
      await open(tester);
      expect(find.text('Your Personal budget starts on 1 Nov'), findsOneWidget);
      final add = tester.widget<FilledButton>(
        find.byKey(const Key('quickAddSave')),
      );
      expect(add.onPressed, isNull);
    });

    testWidgets('a running budget shows no notice', (tester) async {
      await open(tester);
      expect(find.textContaining('Your Personal budget'), findsNothing);
    });
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
