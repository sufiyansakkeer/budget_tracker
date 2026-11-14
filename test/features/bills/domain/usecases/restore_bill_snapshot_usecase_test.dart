import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/bills/data/datasource/bill_local_datasource_impl.dart';
import 'package:monivo/features/bills/data/repository/bill_repository_impl.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/entities/bill_failure.dart';
import 'package:monivo/features/bills/domain/entities/bill_snapshot.dart';
import 'package:monivo/features/bills/domain/usecases/delete_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_paid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/pay_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/restore_bill_snapshot_usecase.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/usecases/delete_expense_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/in_memory_database.dart';

/// UX-100: Undo after mark paid, pay & record and delete puts the bill and
/// its payment history back exactly, deletes the expense the change
/// recorded and leaves the budget's remaining amount as it was. Runs on the
/// real repositories over an in-memory database, so the expense delete
/// recomputes the budget as deleting it from Expenses does.
void main() {
  late AppDatabase database;
  late BillRepositoryImpl bills;
  late BudgetRepositoryImpl budgets;
  late ExpenseRepositoryImpl expenses;
  late RestoreBillSnapshotUseCase restore;
  late PayBillUseCase pay;

  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
  // Stored to the second; a whole second keeps the comparisons exact.
  final created = DateTime(now.year, now.month, now.day - 20, 9, 15);

  BillEntity bill({String? budgetId, bool recurring = false}) => BillEntity(
    id: 'rent',
    title: 'Rent',
    note: 'Flat 4',
    amount: 400,
    currency: 'INR',
    category: BillCategory.rent,
    dueDate: day(2),
    dueTime: DateTime(2000, 1, 1, 9),
    isRecurring: recurring,
    recurrenceType: recurring ? RecurrenceType.monthly : RecurrenceType.none,
    reminderEnabled: true,
    reminderOffsetDays: 1,
    budgetId: budgetId,
    createdAt: created,
    updatedAt: created,
  );

  final earlierPayment = BillPaymentRecord(
    id: 'payment-0',
    billId: 'rent',
    amount: 400,
    currency: 'INR',
    paidDate: created,
    createdAt: created,
  );

  Future<double> remaining() async =>
      (await budgets.getBudgetById('home'))!.remainingAmount;

  Future<BillSnapshot> capture() async =>
      ((await restore.capture('rent')) as BillSuccess<BillSnapshot>).data;

  Future<List<ExpenseEntity>> allExpenses() =>
      expenses.getExpensesForBudgets(budgetIds: const ['home']);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = await createInMemoryDatabase();
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'home',
            name: 'Home',
            monthlyAmount: 5000,
            remainingAmount: 5000,
            currency: 'INR',
            startDate: day(-10),
            endDate: day(20),
          ),
        );
    bills = BillRepositoryImpl(
      localDataSource: BillLocalDataSourceImpl(database: database),
    );
    budgets = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(
        database: database,
        sharedPreferences: await SharedPreferences.getInstance(),
      ),
      calculationService: BudgetCalculationService(),
    );
    await budgets.setActiveBudgetId('home');
    expenses = ExpenseRepositoryImpl(
      localDataSource: ExpenseLocalDataSourceImpl(database: database),
      budgetRepository: budgets,
    );
    restore = RestoreBillSnapshotUseCase(
      repository: bills,
      deleteExpense: DeleteExpenseUseCase(repository: expenses),
    );
    pay = PayBillUseCase(
      billRepository: bills,
      budgetRepository: budgets,
      expenseRepository: expenses,
    );
  });

  tearDown(() => database.close());

  test('capture reads the bill and its payment history', () async {
    await bills.createBill(bill(recurring: true));
    await bills.createBillPayment(earlierPayment);

    final snapshot = await capture();

    expect(snapshot.bill, bill(recurring: true));
    expect(snapshot.payments, [earlierPayment]);
  });

  test('capture of a missing bill is not found', () async {
    final result = await restore.capture('missing');

    expect(
      (result as BillError<BillSnapshot>).failure.type,
      BillErrorType.notFound,
    );
  });

  test('mark paid on a recurring bill: Undo restores its due date and '
      'removes the payment record', () async {
    await bills.createBill(bill(recurring: true));
    await bills.createBillPayment(earlierPayment);
    final before = await capture();

    final paid = await MarkBillPaidUseCase(repository: bills)('rent');
    expect((paid as BillSuccess<BillEntity>).data.dueDate, isNot(day(2)));
    expect(await bills.getBillPayments('rent'), hasLength(2));

    final result = await restore(before);

    expect((result as BillSuccess<BillEntity>).data, before.bill);
    expect(await bills.getBillById('rent'), before.bill);
    expect(await bills.getBillPayments('rent'), [earlierPayment]);
  });

  test('pay & record as plain spending: Undo deletes that expense by id, '
      'restores the bill and the budget remaining', () async {
    // Not linked, so the payment is plain spending from the active budget.
    await bills.createBill(bill());
    final expenseBefore = await allExpenses();
    final remainingBefore = await remaining();
    final before = await capture();

    final outcome = (await pay('rent') as BillSuccess<BillPaymentOutcome>).data;
    expect(outcome.expense.billId, isNull);
    expect(await remaining(), remainingBefore - 400);
    expect((await bills.getBillById('rent'))!.isPaid, isTrue);

    await restore(before, recordedExpenseId: outcome.expense.id);

    expect(await bills.getBillById('rent'), before.bill);
    expect(await bills.getBillPayments('rent'), isEmpty);
    expect(await allExpenses(), expenseBefore);
    expect(await remaining(), remainingBefore);
  });

  test('pay & record on a linked recurring bill: Undo restores the '
      'occurrence and deletes the settling expense', () async {
    await bills.createBill(bill(budgetId: 'home', recurring: true));
    final remainingBefore = await remaining();
    final before = await capture();

    final outcome = (await pay('rent') as BillSuccess<BillPaymentOutcome>).data;
    expect(outcome.expense.billId, 'rent');
    expect(await remaining(), remainingBefore - 400);

    await restore(before, recordedExpenseId: outcome.expense.id);

    expect(await bills.getBillById('rent'), before.bill);
    expect(await bills.getBillPayments('rent'), isEmpty);
    expect(await allExpenses(), isEmpty);
    expect(await remaining(), remainingBefore);
  });

  test('only the recorded expense goes: earlier expenses for the bill are '
      'kept', () async {
    await bills.createBill(bill(budgetId: 'home', recurring: true));
    final earlier = ExpenseEntity(
      id: 'earlier',
      budgetId: 'home',
      amount: 400,
      categoryId: PayBillUseCase.categoryId,
      date: day(-5),
      time: created,
      createdAt: created,
      updatedAt: created,
      billId: 'rent',
    );
    await expenses.createExpense(earlier);
    final before = await capture();

    final outcome = (await pay('rent') as BillSuccess<BillPaymentOutcome>).data;
    await restore(before, recordedExpenseId: outcome.expense.id);

    expect(await allExpenses(), [earlier]);
  });

  test('delete: Undo re-inserts the bill with its id, link and payment '
      'history; its expenses were kept and still point to it', () async {
    await bills.createBill(bill(budgetId: 'home', recurring: true));
    await bills.createBillPayment(earlierPayment);
    final paidEarlier = ExpenseEntity(
      id: 'earlier',
      budgetId: 'home',
      amount: 400,
      categoryId: PayBillUseCase.categoryId,
      date: day(-5),
      time: created,
      createdAt: created,
      updatedAt: created,
      billId: 'rent',
    );
    await expenses.createExpense(paidEarlier);
    final remainingBefore = await remaining();
    final before = await capture();

    await DeleteBillUseCase(repository: bills)('rent');
    expect(await bills.getBillById('rent'), isNull);
    expect(await bills.getBillPayments('rent'), isEmpty);

    await restore(before);

    expect(await bills.getBillById('rent'), before.bill);
    expect(await bills.getBillPayments('rent'), [earlierPayment]);
    expect(await expenses.getExpensesForBill('rent'), [paidEarlier]);
    expect(await remaining(), remainingBefore);
  });

  test('an expense already deleted is skipped; the bill still comes '
      'back', () async {
    await bills.createBill(bill());
    final before = await capture();
    final outcome = (await pay('rent') as BillSuccess<BillPaymentOutcome>).data;
    await expenses.deleteExpense(outcome.expense.id);

    final result = await restore(before, recordedExpenseId: outcome.expense.id);

    expect(result, isA<BillSuccess<BillEntity>>());
    expect(await bills.getBillById('rent'), before.bill);
  });

  test('a failure rolls the whole undo back', () async {
    await bills.createBill(bill(recurring: true));
    final before = await capture();
    await MarkBillPaidUseCase(repository: bills)('rent');
    final paid = await bills.getBillById('rent');
    final payments = await bills.getBillPayments('rent');

    // A payment row for a bill that doesn't exist breaks the foreign key
    // after the bill has already been written back.
    final broken = BillSnapshot(
      bill: before.bill,
      payments: [
        BillPaymentRecord(
          id: 'orphan',
          billId: 'no-such-bill',
          amount: 1,
          currency: 'INR',
          paidDate: created,
          createdAt: created,
        ),
      ],
    );
    final result = await restore(broken);

    expect(result, isA<BillError<BillEntity>>());
    expect(await bills.getBillById('rent'), paid);
    expect(await bills.getBillPayments('rent'), payments);
  });
}
