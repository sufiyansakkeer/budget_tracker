import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/currency/currency_provider.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/primary_button.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/presentation/pages/budget_form_screen.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../expenses/presentation/expense_test_fakes.dart'
    show MemoryExpenseRepository;
import 'budget_form_screen_test.dart' show FakeSettingsRepository;

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  BudgetEntity budget(
    String id,
    String name, {
    required DateTime start,
    required DateTime end,
  }) => BudgetEntity(
    id: id,
    name: name,
    monthlyAmount: 1000,
    remainingAmount: 1000,
    currency: 'INR',
    startDate: start,
    endDate: end,
    createdAt: start,
    updatedAt: start,
  );

  late ListBudgetRepository budgets;

  setUp(() async {
    await getIt.reset();
    budgets = ListBudgetRepository();
    getIt
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(
          repository: budgets,
          reconcileTabs: FakeReconcileTabUseCase(),
        ),
      )
      ..registerSingleton<CurrencyProvider>(
        CurrencyProvider(
          loadSettingsUseCase: LoadSettingsUseCase(
            repository: FakeSettingsRepository(),
          ),
        ),
      );
  });

  tearDown(() async => getIt.reset());

  Future<void> pumpForm(
    WidgetTester tester, {
    String? budgetId,
    double keyboard = 0,
  }) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
          routes: [
            GoRoute(
              path: 'form',
              builder: (_, _) => BudgetFormScreen(budgetId: budgetId),
            ),
          ],
        ),
      ],
    );
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    router.push('/home/form');
    await tester.pumpAndSettle();
  }

  Finder field(String label) =>
      find.widgetWithText(TextFormField, label, skipOffstage: false);

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.ensureVisible(field(label));
    await tester.pumpAndSettle();
    await tester.enterText(field(label), text);
    await tester.pumpAndSettle();
  }

  Finder saveButton(String label) => find.descendant(
    of: find.byType(PrimaryButton),
    matching: find.text(label),
  );

  Future<void> pickStart(WidgetTester tester, DateTime date) async {
    await tester.ensureVisible(find.text('Starts'));
    await tester.tap(find.text('Starts'));
    await tester.pumpAndSettle();
    // Type the date rather than page through months.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/${date.year}',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  group('UX-014 · Save bar and the keyboard', () {
    testWidgets('the save button stays above the keyboard', (tester) async {
      await pumpForm(tester, keyboard: 300);

      final button = tester.getRect(find.byType(PrimaryButton));
      expect(button.bottom, lessThanOrEqualTo(800 - 300));
    });
  });

  group('UX-015 · Which budget a new one makes active', () {
    testWidgets('a budget for later keeps the running one active, and offers '
        '"Make active"', (tester) async {
      budgets.budgets.add(
        budget('oct', 'October', start: day(-5), end: day(20)),
      );
      budgets.activeId = 'oct';
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'November');
      await enter(tester, 'Budget amount', '1000');
      await pickStart(tester, day(30));

      await tester.tap(saveButton('Create budget'));
      await tester.pumpAndSettle();

      expect(budgets.budgets, hasLength(2));
      expect(budgets.activeId, 'oct');
      expect(find.text('Budget created'), findsOneWidget);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Make active'));
      await tester.pumpAndSettle();
      expect(budgets.activeId, isNot('oct'));
      expect(find.text('November is now your active budget'), findsOneWidget);
    });

    testWidgets('a budget running today becomes active', (tester) async {
      budgets.budgets.add(
        budget('oct', 'October', start: day(-5), end: day(20)),
      );
      budgets.activeId = 'oct';
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'Trip');
      await enter(tester, 'Budget amount', '1000');

      await tester.tap(saveButton('Create budget'));
      await tester.pumpAndSettle();

      expect(budgets.activeId, isNot('oct'));
      expect(find.text('Budget created and set active'), findsOneWidget);
    });

    testWidgets('with no running budget active, a budget for later still '
        'becomes active', (tester) async {
      budgets.budgets.add(
        budget('sep', 'September', start: day(-40), end: day(-10)),
      );
      budgets.activeId = 'sep';
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'November');
      await enter(tester, 'Budget amount', '1000');
      await pickStart(tester, day(30));

      await tester.tap(saveButton('Create budget'));
      await tester.pumpAndSettle();

      expect(budgets.activeId, isNot('sep'));
      expect(find.text('Budget created and set active'), findsOneWidget);
    });
  });

  group('UX-024 · Discard changes', () {
    testWidgets('an untouched new budget closes at once', (tester) async {
      await pumpForm(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('a filled new budget asks before discarding', (tester) async {
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'Trip');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard this budget?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('New budget'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(budgets.budgets, isEmpty);
    });

    testWidgets('an edited budget asks; an unchanged one closes at once', (
      tester,
    ) async {
      budgets.budgets.add(
        budget('oct', 'October', start: day(-5), end: day(20)),
      );
      await pumpForm(tester, budgetId: 'oct');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);

      await pumpForm(tester, budgetId: 'oct');
      await enter(tester, 'Budget amount', '1200');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text("Your changes haven't been saved."), findsOneWidget);
    });

    testWidgets('saving closes without asking', (tester) async {
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'Trip');
      await enter(tester, 'Budget amount', '1000');

      await tester.tap(saveButton('Create budget'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this budget?'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('UX-038 · Date edits say what they change', () {
    late MemoryExpenseRepository expenses;

    setUp(() {
      expenses = MemoryExpenseRepository();
      getIt.registerSingleton<GetExpensesUseCase>(
        GetExpensesUseCase(repository: expenses),
      );
      budgets.budgets.add(
        budget('oct', 'October', start: day(-5), end: day(20)),
      );
      for (final (id, offset) in [('a', -4), ('b', -3), ('c', 0)]) {
        expenses.store[id] = ExpenseEntity(
          id: id,
          budgetId: 'oct',
          amount: 10,
          categoryId: 'food',
          date: day(offset),
          time: day(offset),
          createdAt: day(offset),
          updatedAt: day(offset),
        );
      }
    });

    Finder excluded() =>
        find.byKey(const ValueKey('budgetDatesExcludeWarning'));
    Finder notToday() => find.byKey(const ValueKey('budgetDatesNotToday'));

    testWidgets('a later start names the expenses it leaves out', (
      tester,
    ) async {
      await pumpForm(tester, budgetId: 'oct');
      expect(excluded(), findsNothing);

      await pickStart(tester, day(-2));

      expect(excluded(), findsOneWidget);
      expect(find.text('2 expenses fall outside these dates'), findsOneWidget);
      // Not the active budget: Home is not affected.
      expect(notToday(), findsNothing);
    });

    testWidgets('the active budget warns when its dates leave out today', (
      tester,
    ) async {
      budgets.activeId = 'oct';
      await pumpForm(tester, budgetId: 'oct');
      expect(notToday(), findsNothing);

      await pickStart(tester, day(1));

      expect(notToday(), findsOneWidget);
      expect(find.text('3 expenses fall outside these dates'), findsOneWidget);
    });
  });

  group('UX-039 · Clearing the look and notes', () {
    testWidgets('a cleared note, icon and colour are saved as cleared', (
      tester,
    ) async {
      budgets.budgets.add(
        BudgetEntity(
          id: 'trip',
          name: 'Trip',
          monthlyAmount: 1000,
          remainingAmount: 1000,
          currency: 'INR',
          startDate: day(-5),
          endDate: day(20),
          icon: 'travel',
          color: '0xFF2196F3',
          notes: 'Old note',
          createdAt: day(-5),
          updatedAt: day(-5),
        ),
      );
      await pumpForm(tester, budgetId: 'trip');

      await enter(tester, 'Notes', '');
      final travel = find.widgetWithText(ChoiceChip, 'Travel');
      await tester.ensureVisible(travel);
      await tester.tap(travel);
      await tester.pumpAndSettle();
      final blue = find.bySemanticsLabel('Blue colour');
      await tester.ensureVisible(blue);
      await tester.tap(blue);
      await tester.pumpAndSettle();
      await tester.tap(saveButton('Save changes'));
      await tester.pumpAndSettle();

      final saved = budgets.updated.single;
      expect(saved.notes, isNull);
      expect(saved.icon, isNull);
      expect(saved.color, isNull);
    });
  });
}
