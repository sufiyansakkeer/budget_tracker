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
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';
import 'budget_form_screen_test.dart' show FakeSettingsRepository;

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

void main() {
  late ListBudgetRepository budgets;

  setUp(() async {
    await getIt.reset();
    budgets = ListBudgetRepository();
    getIt
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(repository: budgets),
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
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('${CurrencyFormatter.symbolFor(code)}  $code').last,
      );
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
}
