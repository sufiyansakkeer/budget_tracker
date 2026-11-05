import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/dates/date_range_format.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/repository/bill_repository.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_unpaid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/pay_bill_usecase.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/pages/bill_details_screen.dart';
import 'package:monivo/features/bills/presentation/pages/bill_payment_dialogs.dart';
import 'package:monivo/features/bills/presentation/pages/bills_list_screen.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';

import '../../../../helpers/bill_payment_fakes.dart';
import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';

/// UX-100: Undo on bill details (mark paid, pay & record) and after a
/// delete, which pops details, so the Undo is tapped on the bills list once
/// the details' bloc has closed.
void main() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  final household = BudgetEntity(
    id: 'household',
    name: 'Household',
    monthlyAmount: 30000,
    remainingAmount: 30000,
    currency: 'INR',
    startDate: day(-10),
    endDate: day(20),
    createdAt: day(-10),
    updatedAt: day(-10),
  );

  BillEntity rent({bool recurring = false}) => BillEntity(
    id: 'rent',
    title: 'Rent',
    amount: 100,
    currency: 'INR',
    category: BillCategory.rent,
    dueDate: day(3),
    isRecurring: recurring,
    recurrenceType: recurring ? RecurrenceType.monthly : RecurrenceType.none,
    reminderEnabled: false,
    createdAt: day(-30),
    updatedAt: day(-30),
  );

  final earlierPayment = BillPaymentRecord(
    id: 'payment-0',
    billId: 'rent',
    amount: 100,
    currency: 'INR',
    paidDate: day(-27),
    createdAt: day(-27),
  );

  late SafeSpendFakeBillRepository bills;
  late InMemoryExpenseRepository expenses;
  late PayBillUseCase pay;
  late BillBloc Function() originalFactory;

  BillBloc newBloc() =>
      buildTestBillBloc(bills, payBill: pay, expenses: expenses);

  setUp(() async {
    await getIt.reset();
    bills = SafeSpendFakeBillRepository();
    expenses = InMemoryExpenseRepository();
    final budgets = ListBudgetRepository([household], household.id);
    pay = PayBillUseCase(
      billRepository: bills,
      budgetRepository: budgets,
      expenseRepository: expenses,
    );
    getIt
      ..registerSingleton<BillRepository>(bills)
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(
          repository: budgets,
          reconcileTabs: FakeReconcileTabUseCase(),
        ),
      )
      ..registerSingleton<PayBillUseCase>(pay)
      ..registerSingleton<MarkBillUnpaidUseCase>(
        MarkBillUnpaidUseCase(repository: bills, expenseRepository: expenses),
      );
    originalFactory = BillPaymentDialogs.undoBlocFactory;
    BillPaymentDialogs.undoBlocFactory = newBloc;
  });

  tearDown(() async {
    BillPaymentDialogs.undoBlocFactory = originalFactory;
    await getIt.reset();
  });

  /// The bills list with details pushed on top, each route with its own
  /// bloc as in the app (closed when the route goes).
  Future<GoRouter> pumpApp(WidgetTester tester, BillEntity bill) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bills.store[bill.id] = bill;
    final router = GoRouter(
      initialLocation: '/bills',
      routes: [
        GoRoute(
          path: '/bills',
          builder: (_, _) => BlocProvider(
            create: (_) => newBloc(),
            child: const BillsListScreen(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => BlocProvider(
                create: (_) => newBloc(),
                child: BillDetailsScreen(billId: state.pathParameters['id']!),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    router.push('/bills/${bill.id}');
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label, skipOffstage: false).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Finder onDetails(Finder finder) =>
      find.descendant(of: find.byType(BillDetailsScreen), matching: finder);

  // Failed on the old code: details showed a plain snackbar, no Undo.
  testWidgets('details: mark paid on a recurring bill offers Undo, which '
      'moves the due date back and removes the payment', (tester) async {
    final original = rent(recurring: true);
    bills.payments.add(earlierPayment);
    await pumpApp(tester, original);

    await tapButton(tester, 'Mark as paid');
    await tester.tap(find.text('Mark paid'));
    await tester.pumpAndSettle();
    expect(bills.store['rent']!.dueDate, original.nextDueDate);
    expect(bills.payments, hasLength(2));
    expect(
      onDetails(find.text(AppDates.fullDay(original.nextDueDate))),
      findsOne,
    );

    await tester.tap(find.byKey(const Key('billPaidUndoAction')));
    await tester.pumpAndSettle();

    expect(bills.store['rent'], original);
    expect(bills.payments, [earlierPayment]);
    expect(find.text('Payment undone'), findsOneWidget);
    // Details show the restored due date again.
    expect(onDetails(find.text(AppDates.fullDay(original.dueDate))), findsOne);
    expect(
      onDetails(find.text(AppDates.fullDay(original.nextDueDate))),
      findsNothing,
    );
  });

  // Failed on the old code: plain spending offered no Undo anywhere.
  testWidgets('details: pay & record as plain spending offers Undo, which '
      'deletes that expense and restores the bill', (tester) async {
    final original = rent();
    await pumpApp(tester, original);

    await tapButton(tester, 'Mark paid & record expense');
    await tester.tap(find.text('Pay & record'));
    await tester.pumpAndSettle();
    expect(bills.store['rent']!.isPaid, isTrue);
    expect(expenses.store.values.single.billId, isNull);
    final recorded = expenses.store.keys.single;

    await tester.tap(find.byKey(const Key('billPaidUndoAction')));
    await tester.pumpAndSettle();

    expect(expenses.deletedIds, [recorded]);
    expect(expenses.store, isEmpty);
    expect(bills.store['rent'], original);
    expect(bills.payments, isEmpty);
    expect(onDetails(find.text('Mark as unpaid')), findsNothing);
  });

  // Failed on the old code: delete showed "Bill deleted" with no Undo.
  testWidgets('delete pops details; Undo on the list brings the bill back '
      'with its payment history', (tester) async {
    final original = rent(recurring: true);
    bills.payments.add(earlierPayment);
    await pumpApp(tester, original);

    await tapButton(tester, 'Delete bill');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(BillDetailsScreen), findsNothing);
    expect(bills.store, isEmpty);
    expect(find.byKey(const Key('billDeletedUndoSnackBar')), findsOneWidget);
    expect(find.text('Rent'), findsNothing);

    // Details' bloc has closed: the undo runs on a short-lived one.
    await tester.tap(find.byKey(const Key('billDeletedUndoAction')));
    await tester.pumpAndSettle();

    expect(bills.store['rent'], original);
    expect(bills.payments, [earlierPayment]);
    expect(find.text('Bill restored'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
  });
}
