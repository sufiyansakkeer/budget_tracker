import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_card.dart';
import 'package:monivo/core/widgets/primary_button.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/pages/bill_form_screen.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';

// Fixed dates far from any real "today": 2020 has ended, 2099 has not.
BudgetEntity budget(
  String id,
  String name, {
  required DateTime start,
  required DateTime end,
  String currency = 'INR',
  bool archived = false,
}) => BudgetEntity(
  id: id,
  name: name,
  monthlyAmount: 30000,
  remainingAmount: 30000,
  currency: currency,
  startDate: start,
  endDate: end,
  isArchived: archived,
  createdAt: start,
  updatedAt: start,
);

final household = budget(
  'running',
  'Household',
  start: DateTime(2026, 1, 1),
  end: DateTime(2099, 12, 31),
  currency: 'OMR',
);
final nextYear = budget(
  'upcoming',
  'Next year',
  start: DateTime(2098, 1, 1),
  end: DateTime(2098, 12, 31),
);
final summer = budget(
  'ended',
  'Summer 2020',
  start: DateTime(2020, 6, 1),
  end: DateTime(2020, 8, 31),
);
final oldTrip = budget(
  'archived',
  'Old trip',
  start: DateTime(2026, 1, 1),
  end: DateTime(2099, 12, 31),
  archived: true,
);

BillEntity linkedBill() => BillEntity(
  id: 'rent',
  title: 'Rent',
  amount: 100,
  currency: 'INR',
  category: BillCategory.rent,
  dueDate: DateTime(2026, 8, 5),
  budgetId: 'ended',
  reminderEnabled: false,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

void main() {
  late SafeSpendFakeBillRepository bills;
  late BillBloc bloc;

  setUp(() async {
    await getIt.reset();
    bills = SafeSpendFakeBillRepository();
  });

  tearDown(() async {
    await bloc.close();
    await getIt.reset();
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    List<BudgetEntity>? budgets,
    String? billId,
  }) async {
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(
        repository: ListBudgetRepository(
          budgets ?? [household, nextYear, summer, oldTrip],
        ),
      ),
    );
    bloc = buildTestBillBloc(bills);
    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/form',
          builder: (_, _) => BlocProvider.value(
            value: bloc,
            child: BillFormScreen(billId: billId),
          ),
        ),
        GoRoute(
          path: '/app/bills',
          builder: (_, _) => const Scaffold(body: Text('Bills list')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  Finder picker() =>
      find.byWidgetPredicate((w) => w is DropdownButtonFormField<String?>);

  Future<void> openPicker(WidgetTester tester) async {
    await tester.ensureVisible(picker());
    await tester.tap(picker());
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await openPicker(tester);
    await tester.tap(find.textContaining(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String text) async {
    final field = find.widgetWithText(TextField, label, skipOffstage: false);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, text);
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

  testWidgets('a new bill starts not linked and lists running and upcoming '
      'budgets only', (tester) async {
    await pumpForm(tester);

    expect(
      find.descendant(of: picker(), matching: find.text('Not linked')),
      findsOneWidget,
    );
    expect(find.text("Set aside from this budget until it's paid"), findsOne);

    await openPicker(tester);
    expect(find.textContaining('Household ·'), findsOneWidget);
    expect(find.textContaining('Next year ·'), findsOneWidget);
    expect(find.textContaining('Summer 2020'), findsNothing);
    expect(find.textContaining('Old trip'), findsNothing);
    // Close the menu without changing anything.
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();

    await enter(tester, 'Bill name', 'Gym');
    await enter(tester, 'Amount', '40');
    await save(tester, 'Add bill');

    final saved = bills.store.values.single;
    expect(saved.budgetId, isNull);
    expect(saved.currency, 'INR');
  });

  testWidgets('picking a budget in another currency on create switches the '
      'currency without asking', (tester) async {
    await pumpForm(tester);

    await pick(tester, 'Household ·');

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Amount is in OMR, the currency of Household'),
      findsOneWidget,
    );
    final amountField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Amount', skipOffstage: false),
    );
    expect(
      amountField.decoration!.prefixText,
      '${CurrencyFormatter.symbolFor('OMR')} ',
      reason: 'the amount prefix follows the budget currency',
    );

    await enter(tester, 'Bill name', 'Gym');
    await enter(tester, 'Amount', '12');
    await save(tester, 'Add bill');

    final saved = bills.store.values.single;
    expect(saved.budgetId, 'running');
    expect(saved.currency, 'OMR');
  });

  testWidgets('editing keeps a link to an ended budget, labelled ended', (
    tester,
  ) async {
    bills.store['rent'] = linkedBill();
    await pumpForm(tester, billId: 'rent');

    expect(
      find.descendant(of: picker(), matching: find.text('Summer 2020 · ended')),
      findsOneWidget,
    );

    await save(tester, 'Save changes');

    expect(bills.store['rent']!.budgetId, 'ended');
    expect(bills.store['rent']!.currency, 'INR');
  });

  testWidgets('editing asks before switching currency; cancel keeps the '
      'link and currency', (tester) async {
    bills.store['rent'] = linkedBill();
    await pumpForm(tester, billId: 'rent');

    await pick(tester, 'Household ·');
    expect(find.text('Change this bill to OMR?'), findsOneWidget);
    expect(
      find.text(
        "The amount 100 will mean OMR 100. Edit the amount if that's wrong.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: picker(), matching: find.text('Summer 2020 · ended')),
      findsOneWidget,
    );

    await pick(tester, 'Household ·');
    await tester.tap(find.text('Change to OMR'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: picker(), matching: find.text('Household')),
      findsOneWidget,
    );

    await save(tester, 'Save changes');
    expect(bills.store['rent']!.budgetId, 'running');
    expect(bills.store['rent']!.currency, 'OMR');
    expect(bills.store['rent']!.amount, 100);
  });

  testWidgets('choosing "Not linked" on edit removes the link', (tester) async {
    bills.store['rent'] = linkedBill();
    await pumpForm(tester, billId: 'rent');

    await pick(tester, 'Not linked');
    await save(tester, 'Save changes');

    expect(bills.store['rent']!.budgetId, isNull);
  });

  testWidgets('no running or upcoming budget shows an info note, not an '
      'error', (tester) async {
    await pumpForm(tester, budgets: [summer, oldTrip]);

    expect(picker(), findsNothing);
    final card = tester.widget<StatusCard>(
      find.byKey(const ValueKey('billBudgetPickerEmpty')),
    );
    final context = tester.element(find.byType(BillFormScreen));
    expect(card.color, context.appColors.info);
    expect(
      card.message,
      'No budget is running or upcoming. You can link this bill later.',
    );
  });

  testWidgets('category, repeat, reminder and note are folded on a new bill, '
      'with their current values in the summary', (tester) async {
    await pumpForm(tester);
    expect(find.text('Repeat this bill', skipOffstage: false), findsNothing);
    expect(
      // New bills default to a reminder one day before.
      find.textContaining('One-time · 1 day before', skipOffstage: false),
      findsOneWidget,
    );

    final more = find.text('More options', skipOffstage: false);
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Repeat this bill', skipOffstage: false), findsOneWidget);
    expect(find.text('Remind me', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a bill in OMR takes its amount to the fils', (tester) async {
    await pumpForm(tester);
    await pick(tester, 'Household ·');
    await enter(tester, 'Bill name', 'Visa');
    await enter(tester, 'Amount', '12.1259');
    expect(find.text('12.125', skipOffstage: false), findsOneWidget);
    await save(tester, 'Add bill');

    final saved = bills.store.values.single;
    expect(saved.currency, 'OMR');
    expect(saved.amount, 12.125);
  });
}
