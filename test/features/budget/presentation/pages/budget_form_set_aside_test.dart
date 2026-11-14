import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/currency/currency_provider.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/primary_button.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/usecases/get_bills_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/presentation/pages/budget_form_screen.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';
import 'package:monivo/features/settings/presentation/widgets/currency_selector.dart';

import '../../../../helpers/bill_payment_fakes.dart';
import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';
import 'budget_form_screen_test.dart' show FakeSettingsRepository;
import '../../../../helpers/pay_later_fakes.dart';

BudgetEntity augustBudget({double? reserved, double? savings}) => BudgetEntity(
  id: 'aug',
  name: 'August',
  monthlyAmount: 1000,
  remainingAmount: 1000,
  currency: 'INR',
  startDate: DateTime(2026, 8, 1),
  endDate: DateTime(2026, 8, 31),
  reservedAmount: reserved,
  savingsTarget: savings,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

BillEntity bill(
  String id, {
  String? budgetId = 'aug',
  String currency = 'INR',
  bool isPaid = false,
}) => BillEntity(
  id: id,
  title: 'Bill $id',
  amount: 100,
  currency: currency,
  category: BillCategory.utilities,
  dueDate: DateTime(2026, 8, 20),
  budgetId: budgetId,
  isPaid: isPaid,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

/// Refuses updates when told to, for the save-failure path.
class _FailingBudgetRepository extends ListBudgetRepository {
  bool failUpdates = false;

  @override
  Future<BudgetEntity> updateBudget(BudgetEntity budget) async {
    if (failUpdates) throw Exception('disk full');
    return super.updateBudget(budget);
  }
}

void main() {
  late _FailingBudgetRepository budgets;

  setUp(() async {
    await getIt.reset();
    budgets = _FailingBudgetRepository();
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

  Future<void> pumpForm(WidgetTester tester, {String? budgetId}) async {
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
    // A new budget opens "By day" (blueprint); these tests enter a total.
    if (label == 'Budget amount' && field(label).evaluate().isEmpty) {
      await tester.ensureVisible(find.text('By total', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By total'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(field(label));
    await tester.pumpAndSettle();
    await tester.enterText(field(label), text);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Set aside (optional)', () {
    testWidgets('shows both fields, not set, with their helpers', (
      tester,
    ) async {
      await pumpForm(tester);

      expect(
        find.text('Set aside (optional)', skipOffstage: false),
        findsOneWidget,
      );
      expect(field('Keep aside'), findsOneWidget);
      expect(field('Savings goal'), findsOneWidget);
      expect(
        find.text(
          "Money in this budget you don't want counted as spendable",
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Money you want left unspent at the end of the period',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('an amount above the budget amount blocks saving', (
      tester,
    ) async {
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'Trip');
      await enter(tester, 'Budget amount', '1000');
      await enter(tester, 'Keep aside', '1500');

      expect(
        find.text(
          "This can't be more than the budget amount.",
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      await save(tester, 'Create budget');
      expect(budgets.budgets, isEmpty);
    });

    testWidgets('a budget amount at the 1e12 limit blocks saving (review: '
        'a 1e17 budget overflowed the engine)', (tester) async {
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'Trip');
      await enter(tester, 'Budget amount', '100000000000000000');

      await save(tester, 'Create budget');
      expect(
        find.text(
          'Enter an amount less than 1,000,000,000,000.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(budgets.budgets, isEmpty);
    });

    testWidgets('together taking the whole amount warns but still saves', (
      tester,
    ) async {
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'Trip');
      await enter(tester, 'Budget amount', '1000');
      await enter(tester, 'Keep aside', '600');
      await enter(tester, 'Savings goal', '400');

      final total = CurrencyFormatter.format(1000, code: 'INR');
      expect(
        find.text(
          'Together these set aside $total of $total, so nothing will be '
          'free to spend.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      await enter(tester, 'Savings goal', '300');
      expect(
        find.byKey(
          const ValueKey('budgetSetAsideWarning'),
          skipOffstage: false,
        ),
        findsNothing,
      );

      await save(tester, 'Create budget');
      final created = budgets.budgets.single;
      expect(created.reservedAmount, 600);
      expect(created.savingsTarget, 300);
    });

    testWidgets('empty fields create a budget with neither set', (
      tester,
    ) async {
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'Trip');
      await enter(tester, 'Budget amount', '1000');

      await save(tester, 'Create budget');
      final created = budgets.budgets.single;
      expect(created.reservedAmount, isNull);
      expect(created.savingsTarget, isNull);
    });

    testWidgets('editing shows saved values and clearing one stores not set '
        '(null), while 0 stays 0', (tester) async {
      budgets.budgets.add(augustBudget(reserved: 250, savings: 100));
      await pumpForm(tester, budgetId: 'aug');

      expect(
        tester.widget<TextFormField>(field('Keep aside')).controller!.text,
        '250',
      );
      await enter(tester, 'Keep aside', '');
      await enter(tester, 'Savings goal', '0');

      await save(tester, 'Save changes');
      final saved = budgets.updated.single;
      expect(saved.reservedAmount, isNull);
      expect(saved.savingsTarget, 0);
    });
  });

  group('currency change with linked bills', () {
    Future<void> pickCurrency(WidgetTester tester, String code) async {
      await tester.tap(find.byType(CurrencyPickerField));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CurrencyListTile, code));
      await tester.pumpAndSettle();
    }

    testWidgets('warns that unpaid linked bills in the old currency stop '
        'counting', (tester) async {
      budgets.budgets.add(augustBudget());
      getIt.registerSingleton<GetBillsUseCase>(
        GetBillsUseCase(
          repository: SafeSpendFakeBillRepository([
            bill('a'),
            bill('b'),
            bill('paid', isPaid: true),
            bill('other', budgetId: 'sep'),
            bill('unlinked', budgetId: null),
          ]),
        ),
      );
      await pumpForm(tester, budgetId: 'aug');

      const warning =
          "2 linked bills are in INR and won't be counted until you update "
          'them.';
      expect(find.text(warning), findsNothing);

      await pickCurrency(tester, 'OMR');
      expect(find.text(warning), findsOneWidget);

      await pickCurrency(tester, 'INR');
      expect(find.text(warning), findsNothing);
    });

    testWidgets('no warning when no bill is linked', (tester) async {
      budgets.budgets.add(augustBudget());
      getIt.registerSingleton<GetBillsUseCase>(
        GetBillsUseCase(
          repository: SafeSpendFakeBillRepository([
            bill('unlinked', budgetId: null),
          ]),
        ),
      );
      await pumpForm(tester, budgetId: 'aug');

      await pickCurrency(tester, 'OMR');
      expect(
        find.byKey(const ValueKey('budgetCurrencyBillsWarning')),
        findsNothing,
      );
    });
  });

  group('UX-004: a currency change never relabels expenses silently', () {
    Future<void> pickCurrency(WidgetTester tester, String code) async {
      // Fully in view, not just its edge under the app bar.
      await tester.ensureVisible(find.byType(CurrencyPickerField));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CurrencyPickerField));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CurrencyListTile, code));
      await tester.pumpAndSettle();
    }

    ExpenseEntity spent(String id) => ExpenseEntity(
      id: id,
      budgetId: 'aug',
      amount: 500,
      categoryId: 'food',
      date: DateTime(2026, 8, 5),
      time: DateTime(2026, 8, 5, 12),
      createdAt: DateTime(2026, 8, 5, 12),
      updatedAt: DateTime(2026, 8, 5, 12),
    );

    void registerExpenses(List<ExpenseEntity> expenses) {
      getIt.registerSingleton<GetExpensesUseCase>(
        GetExpensesUseCase(repository: InMemoryExpenseRepository(expenses)),
      );
    }

    testWidgets('warns inline, asks before saving, and keeping the old '
        'currency saves nothing', (tester) async {
      budgets.budgets.add(augustBudget());
      registerExpenses([spent('a'), spent('b')]);
      await pumpForm(tester, budgetId: 'aug');

      const inline =
          'The 2 expenses in this budget keep their amounts and will be '
          'counted in OMR. Nothing is converted.';
      expect(find.text(inline), findsNothing);
      await pickCurrency(tester, 'OMR');
      expect(find.text(inline), findsOneWidget);

      await save(tester, 'Save changes');
      expect(find.text('Change currency to OMR?'), findsOneWidget);
      expect(
        find.textContaining('An expense of ₹500 will read'),
        findsOneWidget,
      );

      await tester.tap(find.text('Keep INR'));
      await tester.pumpAndSettle();
      expect(budgets.budgets.single.currency, 'INR', reason: 'not saved');
      expect(find.text(inline), findsOneWidget, reason: 'still editing');

      await save(tester, 'Save changes');
      await tester.tap(find.text('Change currency'));
      await tester.pumpAndSettle();
      expect(budgets.budgets.single.currency, 'OMR');
    });

    testWidgets('a budget holding tab purchases keeps its currency and '
        'says why (I1)', (tester) async {
      await getIt.unregister<ManageBudgetUseCase>();
      getIt.registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(
          repository: budgets,
          reconcileTabs: FakeReconcileTabUseCase()..purchasesInBudget = 2,
        ),
      );
      budgets.budgets.add(augustBudget());
      registerExpenses([spent('a'), spent('b')]);
      await pumpForm(tester, budgetId: 'aug');

      const why =
          '2 purchases in this budget are on Pay later tabs in INR. Move '
          'them to another INR budget or take them off their tab first.';
      expect(find.text(why), findsNothing);
      await pickCurrency(tester, 'OMR');
      expect(find.text(why), findsOneWidget);

      await save(tester, 'Save changes');
      expect(find.text('Change currency to OMR?'), findsNothing);
      expect(budgets.budgets.single.currency, 'INR', reason: 'not saved');
      // UX-097: said in a snackbar, wherever the form is scrolled to, with
      // the reason beside the currency in view.
      const saveError = 'Keep this budget in INR to save.';
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(saveError),
        ),
        findsOneWidget,
      );
      expect(find.text(why).hitTestable(), findsOneWidget);

      // Back to INR: the reason goes and other edits save.
      await tester.scrollUntilVisible(
        find.byType(CurrencyPickerField),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await pickCurrency(tester, 'INR');
      expect(find.text(why), findsNothing);
      await save(tester, 'Save changes');
      expect(budgets.budgets.single.currency, 'INR');
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('a budget with no expenses changes currency without asking', (
      tester,
    ) async {
      budgets.budgets.add(augustBudget());
      registerExpenses(const []);
      await pumpForm(tester, budgetId: 'aug');

      await pickCurrency(tester, 'OMR');
      expect(
        find.byKey(const ValueKey('budgetCurrencyExpensesWarning')),
        findsNothing,
      );
      await save(tester, 'Save changes');
      expect(find.text('Change currency to OMR?'), findsNothing);
      expect(budgets.budgets.single.currency, 'OMR');
    });

    testWidgets('when the expenses cannot be counted it still asks', (
      tester,
    ) async {
      budgets.budgets.add(augustBudget());
      await pumpForm(tester, budgetId: 'aug');

      await pickCurrency(tester, 'OMR');
      expect(
        find.text(
          'The expenses in this budget keep their amounts and will be '
          'counted in OMR. Nothing is converted.',
        ),
        findsOneWidget,
      );
      await save(tester, 'Save changes');
      expect(find.text('Change currency to OMR?'), findsOneWidget);
    });
  });

  group('More options', () {
    testWidgets('icon, colour and notes are folded on a new budget', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(field('Notes'), findsNothing);
      expect(
        find.text('Icon, colour and notes', skipOffstage: false),
        findsOne,
      );

      final more = find.text('More options', skipOffstage: false);
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(field('Notes'), findsOneWidget);
    });

    testWidgets('they are open when editing a budget', (tester) async {
      budgets.budgets.add(augustBudget());
      await pumpForm(tester, budgetId: 'aug');
      expect(field('Notes'), findsOneWidget);
    });
  });
  group('UX-097: Save shows what stopped it', () {
    testWidgets('brings the first invalid field into view', (tester) async {
      await pumpForm(tester);
      await enter(tester, 'Budget name', 'Trip');
      await enter(tester, 'Budget amount', '100');
      await enter(tester, 'Savings goal', '500');
      // Back to the top, the savings goal out of sight.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(field('Budget name').hitTestable(), findsOneWidget);
      expect(field('Savings goal').hitTestable(), findsNothing);

      await save(tester, 'Create budget');

      expect(budgets.budgets, isEmpty, reason: 'not saved');
      expect(field('Savings goal').hitTestable(), findsOneWidget);
      expect(
        find.text("This can't be more than the budget amount."),
        findsOneWidget,
      );
    });

    testWidgets('a failed save is said in a snackbar', (tester) async {
      budgets.failUpdates = true;
      budgets.budgets.add(augustBudget());
      await pumpForm(tester, budgetId: 'aug');
      await enter(tester, 'Budget name', 'August trip');

      await save(tester, 'Save changes');

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text("Couldn't save your changes. Try again."),
        ),
        findsOneWidget,
      );
      expect(find.text('Home'), findsNothing, reason: 'still editing');
    });
  });
  testWidgets('UX-098: the currency box has a minimum height, not a fixed '
      'one', (tester) async {
    await pumpForm(tester);

    // UX-110: the currency is a field like the amount beside it, sized by
    // its content and the theme, so it grows with large text.
    final currency = tester.getSize(find.byType(CurrencyPickerField));
    expect(currency.height, greaterThanOrEqualTo(56));
    // A new budget opens by the day (blueprint).
    final amount = tester.getSize(
      find.widgetWithText(TextFormField, 'Daily target'),
    );
    expect(currency.height, lessThanOrEqualTo(amount.height));
  });

  group('per day (blueprint: "by day")', () {
    test('the amount over the days, after money set aside, floored', () {
      expect(
        BudgetFormScreen.perDayLine(
          amount: 31000,
          reserved: null,
          savings: null,
          days: 31,
          currency: 'INR',
        ),
        "That's about ₹1,000 a day for 31 days, before bills.",
      );
      expect(
        BudgetFormScreen.perDayLine(
          amount: 31000,
          reserved: 1000,
          savings: 2000,
          days: 30,
          currency: 'INR',
        ),
        "That's about ₹933.33 a day for 30 days, after money set aside "
        'and before bills.',
      );
    });

    test(
      'nothing to say without an amount, or when set-asides take it all',
      () {
        String? line(double amount, double? savings) =>
            BudgetFormScreen.perDayLine(
              amount: amount,
              reserved: null,
              savings: savings,
              days: 30,
              currency: 'INR',
            );
        expect(line(0, null), isNull);
        expect(line(1000, 1000), isNull);
      },
    );

    testWidgets('the form says it as the amount is typed', (tester) async {
      await pumpForm(tester);
      expect(
        find.textContaining('a day for', skipOffstage: false),
        findsNothing,
      );
      await enter(tester, 'Budget amount', '3100');
      expect(
        find.textContaining('a day for 31 days', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('By day (blueprint)', () {
    testWidgets('a new budget starts by the day: the total follows', (
      tester,
    ) async {
      await pumpForm(tester);

      expect(field('Daily target'), findsOneWidget);
      expect(field('Budget amount'), findsNothing);
      await enter(tester, 'Budget name', 'Household');
      await enter(tester, 'Daily target', '100');
      await enter(tester, 'Savings goal', '300');

      // 31 days by default.
      expect(
        find.text('₹100 a day × 31 days + ₹300 savings', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('₹3,400', skipOffstage: false), findsOneWidget);
      expect(
        find.text('Saved as the budget amount', skipOffstage: false),
        findsOneWidget,
      );

      await save(tester, 'Create budget');
      final saved = (await budgets.getAllBudgets()).single;
      expect(saved.monthlyAmount, 3400);
      expect(saved.savingsTarget, 300);
    });

    testWidgets('switching to the total carries the figure over', (
      tester,
    ) async {
      await pumpForm(tester);
      await enter(tester, 'Daily target', '100');
      await tester.ensureVisible(find.text('By total', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By total'));
      await tester.pumpAndSettle();

      final total = tester.widget<TextFormField>(field('Budget amount'));
      expect(total.controller!.text, '3100');
    });
  });
}
