import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/entities/bill_failure.dart';
import 'package:monivo/features/bills/domain/repository/bill_repository.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_unpaid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/pay_bill_usecase.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/pages/bill_details_screen.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';

import '../../../../helpers/bill_payment_fakes.dart';
import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';

final household = BudgetEntity(
  id: 'household',
  name: 'Household',
  monthlyAmount: 30000,
  remainingAmount: 30000,
  currency: 'INR',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2099, 12, 31),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

BillEntity rent({String? budgetId, bool isPaid = false}) => BillEntity(
  id: 'rent',
  title: 'Rent',
  amount: 100,
  currency: 'INR',
  category: BillCategory.rent,
  dueDate: DateTime(2026, 10, 5),
  budgetId: budgetId,
  reminderEnabled: false,
  isPaid: isPaid,
  paidDate: isPaid ? DateTime(2026, 10, 5, 10) : null,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

void main() {
  late SafeSpendFakeBillRepository bills;
  late InMemoryExpenseRepository expenses;
  late FakePayBillUseCase payBill;
  late BillBloc bloc;

  setUp(() async {
    await getIt.reset();
    bills = SafeSpendFakeBillRepository();
    expenses = InMemoryExpenseRepository();
    payBill = FakePayBillUseCase(
      const BillError(
        BillFailure(type: BillErrorType.databaseFailure, message: 'not run'),
      ),
      target: BillSuccess(household),
    );
    getIt
      ..registerSingleton<BillRepository>(bills)
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(repository: ListBudgetRepository([household])),
      )
      ..registerSingleton<PayBillUseCase>(payBill)
      ..registerSingleton<MarkBillUnpaidUseCase>(
        MarkBillUnpaidUseCase(repository: bills, expenseRepository: expenses),
      );
  });

  tearDown(() async {
    await bloc.close();
    await getIt.reset();
  });

  Future<void> pumpDetails(WidgetTester tester, BillEntity bill) async {
    bills.store[bill.id] = bill;
    bloc = buildTestBillBloc(bills, payBill: payBill, expenses: expenses);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider.value(
          value: bloc,
          child: BillDetailsScreen(billId: bill.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label, skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  // FilledButton.icon / OutlinedButton.icon build private subclasses.
  Finder button<T>(String label) => find.ancestor(
    of: find.text(label, skipOffstage: false),
    matching: find.byWidgetPredicate((w) => w is T),
  );

  Finder paidFrom(String value) => find.descendant(
    of: find.byKey(const ValueKey('paidFrom')),
    matching: find.text(value),
  );

  group('linked bill', () {
    testWidgets('shows where it is paid from, with record-expense as the '
        'primary action', (tester) async {
      await pumpDetails(tester, rent(budgetId: 'household'));

      expect(paidFrom('Paid from'), findsOneWidget);
      expect(paidFrom('Household'), findsOneWidget);
      expect(
        button<FilledButton>('Mark paid & record expense'),
        findsOneWidget,
      );
      expect(
        button<OutlinedButton>('Paid outside this budget'),
        findsOneWidget,
      );
      expect(find.text('Mark as paid'), findsNothing);
      expect(find.text('Mark paid & add expense'), findsNothing);
    });

    testWidgets('record expense names the budget and pays through PayBill', (
      tester,
    ) async {
      await pumpDetails(tester, rent(budgetId: 'household'));

      await tapButton(tester, 'Mark paid & record expense');
      expect(find.text('Mark paid & record expense?'), findsOneWidget);
      expect(
        find.text(
          '"Rent" will be marked paid and an expense of ₹100 will be '
          'recorded in Household.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(payBill.paidBillIds, ['rent']);
    });

    testWidgets('paid outside this budget warns that the set-aside money is '
        'released, then marks paid without an expense', (tester) async {
      await pumpDetails(tester, rent(budgetId: 'household'));

      await tapButton(tester, 'Paid outside this budget');
      expect(
        find.text(
          '"Rent" won\'t be recorded as an expense, so ₹100 will stop being '
          "set aside and Household's safe-to-spend will go up by that amount. "
          'Use this only if you paid it from money outside this budget.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Mark paid'));
      await tester.pumpAndSettle();

      expect(bills.store['rent']!.isPaid, isTrue);
      expect(payBill.paidBillIds, isEmpty);
      expect(expenses.store, isEmpty);
    });

    group('when the linked budget sets nothing aside for it (review: the '
        'dialog promised a safe-to-spend rise)', () {
      Future<void> useBudget(BudgetEntity budget) async {
        await getIt.unregister<ManageBudgetUseCase>();
        getIt.registerSingleton<ManageBudgetUseCase>(
          ManageBudgetUseCase(repository: ListBudgetRepository([budget])),
        );
      }

      Future<void> expectPlainMarkPaid(WidgetTester tester) async {
        await tapButton(tester, 'Paid outside this budget');
        expect(find.textContaining('safe-to-spend'), findsNothing);
        expect(find.text('"Rent" will be marked as paid.'), findsOneWidget);
        await tester.tap(find.text('Mark paid'));
        await tester.pumpAndSettle();
        expect(bills.store['rent']!.isPaid, isTrue);
        expect(expenses.store, isEmpty);
      }

      testWidgets('archived budget: plain mark-paid wording', (tester) async {
        await useBudget(household.copyWith(isArchived: true));
        await pumpDetails(tester, rent(budgetId: 'household'));
        await expectPlainMarkPaid(tester);
      });

      testWidgets('budget in another currency: plain mark-paid wording', (
        tester,
      ) async {
        await useBudget(household.copyWith(currency: 'USD'));
        await pumpDetails(tester, rent(budgetId: 'household'));
        await expectPlainMarkPaid(tester);
      });

      testWidgets('budget that ended: plain mark-paid wording', (tester) async {
        await useBudget(
          household.copyWith(
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 30),
          ),
        );
        await pumpDetails(tester, rent(budgetId: 'household'));
        await expectPlainMarkPaid(tester);
      });
    });

    testWidgets('when no budget can take the payment it says why instead of '
        'asking', (tester) async {
      payBill.target = const BillError(
        BillFailure(
          type: BillErrorType.invalidInput,
          message: 'No running budget in INR to record this payment',
        ),
      );
      await pumpDetails(tester, rent(budgetId: 'household'));

      await tapButton(tester, 'Mark paid & record expense');

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('No running budget in INR to record this payment'),
        findsOneWidget,
      );
      expect(payBill.paidBillIds, isEmpty);
    });

    testWidgets('mark as unpaid names the expense it deletes', (tester) async {
      expenses.store['e1'] = ExpenseEntity(
        id: 'e1',
        budgetId: 'household',
        amount: 100,
        categoryId: 'bills',
        note: 'Bill: Rent',
        date: DateTime(2026, 10, 5),
        time: DateTime(2026, 10, 5, 10),
        createdAt: DateTime(2026, 10, 5, 10),
        updatedAt: DateTime(2026, 10, 5, 10),
        billId: 'rent',
      );
      await pumpDetails(tester, rent(budgetId: 'household', isPaid: true));

      await tapButton(tester, 'Mark as unpaid');
      expect(
        find.text(
          '"Rent" will go back to unpaid and the expense "Bill: Rent" '
          '(₹100, 5 Oct 2026) recorded for it will be deleted.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Mark unpaid'));
      await tester.pumpAndSettle();

      expect(bills.store['rent']!.isPaid, isFalse);
      expect(expenses.deletedIds, ['e1']);
    });
    testWidgets('mark as unpaid when the expense lookup fails says the '
        'payment expense will be deleted, never that it is kept (review)', (
      tester,
    ) async {
      expenses.store['e1'] = ExpenseEntity(
        id: 'e1',
        budgetId: 'household',
        amount: 100,
        categoryId: 'bills',
        note: 'Bill: Rent',
        date: DateTime(2026, 10, 5),
        time: DateTime(2026, 10, 5, 10),
        createdAt: DateTime(2026, 10, 5, 10),
        updatedAt: DateTime(2026, 10, 5, 10),
        billId: 'rent',
      );
      await getIt.unregister<MarkBillUnpaidUseCase>();
      getIt.registerSingleton<MarkBillUnpaidUseCase>(
        _PreviewFailsMarkBillUnpaidUseCase(bills, expenses),
      );
      await pumpDetails(tester, rent(budgetId: 'household', isPaid: true));

      await tapButton(tester, 'Mark as unpaid');
      expect(find.textContaining('are kept'), findsNothing);
      expect(
        find.text(
          '"Rent" will go back to unpaid. Any expense recorded when it was '
          'marked paid will be deleted.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Mark unpaid'));
      await tester.pumpAndSettle();

      expect(bills.store['rent']!.isPaid, isFalse);
      expect(expenses.deletedIds, ['e1']);
    });
  });

  group('unlinked bill', () {
    testWidgets('says it is not linked and keeps both existing actions', (
      tester,
    ) async {
      await pumpDetails(tester, rent());

      expect(paidFrom('Not linked'), findsOneWidget);
      expect(button<FilledButton>('Mark as paid'), findsOneWidget);
      expect(find.text('Mark paid & add expense'), findsOneWidget);
      expect(find.text('Paid outside this budget'), findsNothing);
    });

    testWidgets('mark as paid keeps the plain confirmation', (tester) async {
      await pumpDetails(tester, rent());

      await tapButton(tester, 'Mark as paid');
      expect(find.text('"Rent" will be marked as paid.'), findsOneWidget);
      await tester.tap(find.text('Mark paid'));
      await tester.pumpAndSettle();

      expect(bills.store['rent']!.isPaid, isTrue);
      expect(payBill.paidBillIds, isEmpty);
    });

    testWidgets('mark as unpaid without a recorded expense keeps expenses', (
      tester,
    ) async {
      await pumpDetails(tester, rent(isPaid: true));

      await tapButton(tester, 'Mark as unpaid');
      expect(
        find.text(
          '"Rent" will go back to unpaid. Expenses already recorded for it '
          'are kept.',
        ),
        findsOneWidget,
      );
    });
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final linked = rent(budgetId: 'household');
      bills.store[linked.id] = linked;
      bloc = buildTestBillBloc(bills, payBill: payBill, expenses: expenses);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1600),
              textScaler: const TextScaler.linear(2),
            ),
            child: BlocProvider.value(
              value: bloc,
              child: BillDetailsScreen(billId: linked.id),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

/// The real use case, except the confirmation's preview read fails.
class _PreviewFailsMarkBillUnpaidUseCase extends MarkBillUnpaidUseCase {
  _PreviewFailsMarkBillUnpaidUseCase(
    BillRepository bills,
    InMemoryExpenseRepository expenses,
  ) : super(repository: bills, expenseRepository: expenses);

  @override
  Future<BillResult<List<ExpenseEntity>>> expensesToRemove(
    String billId,
  ) async => const BillError(
    BillFailure(type: BillErrorType.databaseFailure, message: 'busy'),
  );
}
