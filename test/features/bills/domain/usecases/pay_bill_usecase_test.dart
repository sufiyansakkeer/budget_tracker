import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/domain/services/database_integrity_service.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/entities/bill_failure.dart';
import 'package:monivo/features/bills/domain/usecases/link_bills_to_budget_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_unpaid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/pay_bill_usecase.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';

import '../../../../integration/app_harness.dart';

/// Paying a bill, undoing a payment and linking bills, against the real
/// repositories on an in-memory database (so transactions really roll back).
void main() {
  late AppHarness app;
  late PayBillUseCase payBill;
  late MarkBillUnpaidUseCase markUnpaid;

  /// 10 Aug 2026, 09:30 — inside the August budget.
  final now = DateTime(2026, 8, 10, 9, 30);
  final today = DateTime(2026, 8, 10);

  setUp(() async {
    app = await AppHarness.create();
    payBill = PayBillUseCase(
      billRepository: app.billRepository,
      budgetRepository: app.budgetRepository,
      expenseRepository: app.expenseRepository,
      clock: () => now,
    );
    markUnpaid = MarkBillUnpaidUseCase(
      repository: app.billRepository,
      expenseRepository: app.expenseRepository,
    );
  });
  tearDown(() => app.dispose());

  Future<BudgetEntity> august({
    String id = 'aug',
    String currency = 'INR',
    bool makeActive = true,
  }) => app.addBudget(
    id: id,
    name: 'August $id',
    amount: 30000,
    currency: currency,
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 31),
    makeActive: makeActive,
  );

  Future<BillEntity> addBill({
    String id = 'rent',
    double amount = 12000,
    String currency = 'INR',
    DateTime? dueDate,
    bool recurring = true,
    String? budgetId,
  }) async {
    final bill = BillEntity(
      id: id,
      title: 'Bill $id',
      amount: amount,
      currency: currency,
      category: BillCategory.rent,
      dueDate: dueDate ?? DateTime(2026, 8, 15),
      isRecurring: recurring,
      recurrenceType: recurring ? RecurrenceType.monthly : RecurrenceType.none,
      budgetId: budgetId,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );
    await app.billRepository.createBill(bill);
    return bill;
  }

  Future<List<ExpenseEntity>> expensesOf(String budgetId) =>
      app.expenseRepository.getExpenses(budgetId: budgetId);

  BillPaymentOutcome paid(BillResult<BillPaymentOutcome> result) =>
      (result as BillSuccess<BillPaymentOutcome>).data;

  BillFailure failed(BillResult<Object?> result) =>
      (result as BillError<Object?>).failure;

  group('PayBillUseCase — writes', () {
    test('records the payment, advances a recurring bill and adds the '
        'expense to the linked budget in one go', () async {
      await august();
      await addBill(budgetId: 'aug');

      final outcome = paid(await payBill('rent'));

      expect(outcome.budget.id, 'aug');
      expect(outcome.bill.dueDate, DateTime(2026, 9, 15));
      expect(outcome.bill.isPaid, isFalse);
      expect(
        (await app.billRepository.getBillById('rent'))!.dueDate,
        DateTime(2026, 9, 15),
      );

      final payments = await app.billRepository.getBillPayments('rent');
      expect(payments.single.amount, 12000);
      expect(payments.single.paidDate, now);

      final expense = (await expensesOf('aug')).single;
      expect(expense.amount, 12000);
      expect(expense.categoryId, 'bills');
      expect(expense.note, 'Bill: Bill rent');
      expect(expense.date, today);
      expect(expense.time, now);
      expect(expense.billId, 'rent');
      expect(outcome.expense, expense);
      expect(outcome.settledSetAside, isTrue);
      expect(
        await app.storedRemaining('aug'),
        18000,
        reason: 'remaining is recomputed by the expense repository',
      );
    });

    test('a one-time bill is marked paid at the payment time', () async {
      await august();
      await addBill(recurring: false, budgetId: 'aug');

      final outcome = paid(await payBill('rent'));

      expect(outcome.bill.isPaid, isTrue);
      expect(outcome.bill.paidDate, now);
      expect(outcome.bill.dueDate, DateTime(2026, 8, 15));
    });

    test('an already-paid bill is refused', () async {
      await august();
      await addBill(recurring: false, budgetId: 'aug');
      await payBill('rent');

      final failure = failed(await payBill('rent'));

      expect(failure.type, BillErrorType.invalidInput);
      expect((await expensesOf('aug')).length, 1);
      expect((await app.billRepository.getBillPayments('rent')).length, 1);
    });

    test('a missing bill is notFound', () async {
      expect(failed(await payBill('nope')).type, BillErrorType.notFound);
    });

    test('nothing is written when the expense cannot be stored', () async {
      await august();
      await addBill(budgetId: 'aug');
      // The expense insert fails on its category foreign key, after the
      // payment record and the bill update were already written.
      await (app.database.delete(
        app.database.categories,
      )..where((c) => c.id.equals('bills'))).go();

      final failure = failed(await payBill('rent'));

      expect(failure.type, BillErrorType.databaseFailure);
      expect(await app.billRepository.getBillPayments('rent'), isEmpty);
      expect(
        (await app.billRepository.getBillById('rent'))!.dueDate,
        DateTime(2026, 8, 15),
      );
      expect(await expensesOf('aug'), isEmpty);
      expect(await app.storedRemaining('aug'), 30000);
    });
  });

  group('PayBillUseCase — which budget, and committed or plain', () {
    test('an occurrence overdue from before the period is still set aside '
        '(carried in), so the payment is committed', () async {
      await august();
      await addBill(dueDate: DateTime(2026, 7, 20), budgetId: 'aug');

      final outcome = paid(await payBill('rent'));

      expect(outcome.expense.billId, 'rent');
    });

    test('paying next period\'s occurrence early is plain spending', () async {
      await august();
      await addBill(dueDate: DateTime(2026, 9, 5), budgetId: 'aug');

      final outcome = paid(await payBill('rent'));

      expect(outcome.budget.id, 'aug');
      expect(
        outcome.expense.billId,
        isNull,
        reason: 'it was never deducted from August',
      );
    });

    test(
      'an unlinked bill goes to the active budget as plain spending',
      () async {
        await august();
        await addBill();

        final outcome = paid(await payBill('rent'));

        expect(outcome.budget.id, 'aug');
        expect(outcome.expense.billId, isNull);
      },
    );

    test('a bill linked to an ended budget goes to the running active '
        'budget as plain spending', () async {
      await app.addBudget(
        id: 'jul',
        currency: 'INR',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 31),
        makeActive: false,
      );
      await august();
      await addBill(budgetId: 'jul');

      final outcome = paid(await payBill('rent'));

      expect(outcome.budget.id, 'aug');
      expect(outcome.expense.billId, isNull);
      expect(await expensesOf('jul'), isEmpty);
    });

    test(
      'a bill linked to an archived budget goes to the active budget',
      () async {
        await august(id: 'old', makeActive: false);
        await app.budgetRepository.setBudgetArchived('old', archived: true);
        await august();
        await addBill(budgetId: 'old');

        final outcome = paid(await payBill('rent'));

        expect(outcome.budget.id, 'aug');
        expect(outcome.expense.billId, isNull);
      },
    );

    test('a linked budget in another currency is skipped', () async {
      await august(id: 'usd', currency: 'USD', makeActive: false);
      await august();
      await addBill(budgetId: 'usd');

      final outcome = paid(await payBill('rent'));

      expect(outcome.budget.id, 'aug');
      expect(outcome.expense.billId, isNull);
      expect(await expensesOf('usd'), isEmpty);
    });

    test('the linked budget wins over the active one', () async {
      await august(id: 'linked', makeActive: false);
      await august();
      await addBill(budgetId: 'linked');

      final outcome = paid(await payBill('rent'));

      expect(outcome.budget.id, 'linked');
      expect(outcome.expense.billId, 'rent');
      expect(await expensesOf('aug'), isEmpty);
    });

    test(
      'with no running budget in the bill\'s currency nothing is written',
      () async {
        await august(currency: 'USD');
        await addBill();

        final failure = failed(await payBill('rent'));

        expect(failure.type, BillErrorType.invalidInput);
        expect(
          failure.message,
          'No running budget in INR to record this payment',
        );
        expect(await app.billRepository.getBillPayments('rent'), isEmpty);
        expect(
          (await app.billRepository.getBillById('rent'))!.dueDate,
          DateTime(2026, 8, 15),
        );
        expect(await expensesOf('aug'), isEmpty);
      },
    );

    test(
      'an active budget that has not started cannot take the payment',
      () async {
        await app.addBudget(
          id: 'sep',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
        );
        await addBill(budgetId: 'sep');

        final failure = failed(await payBill('rent'));

        expect(failure.type, BillErrorType.invalidInput);
        expect(await expensesOf('sep'), isEmpty);
      },
    );

    test('targetBudgetFor names the budget without writing anything', () async {
      await august(id: 'linked', makeActive: false);
      await august();
      await addBill(budgetId: 'linked');

      final target = await payBill.targetBudgetFor('rent');

      expect((target as BillSuccess<BudgetEntity>).data.id, 'linked');
      expect(await app.billRepository.getBillPayments('rent'), isEmpty);
    });
  });

  group('MarkBillUnpaidUseCase', () {
    test('undoes a set-aside payment: payment record and expense deleted, '
        'remaining restored', () async {
      await august();
      await addBill(recurring: false, budgetId: 'aug');
      await payBill('rent');
      expect(await app.storedRemaining('aug'), 18000);

      final preview = await markUnpaid.expensesToRemove('rent');
      expect(
        (preview as BillSuccess<List<ExpenseEntity>>).data.single.note,
        'Bill: Bill rent',
      );

      final result = await markUnpaid('rent');

      final bill = (result as BillSuccess<BillEntity>).data;
      expect(bill.isPaid, isFalse);
      expect(bill.paidDate, isNull);
      expect((await app.billRepository.getBillById('rent'))!.isPaid, isFalse);
      expect(await app.billRepository.getBillPayments('rent'), isEmpty);
      expect(await expensesOf('aug'), isEmpty);
      expect(await app.storedRemaining('aug'), 30000);
    });

    test(
      'keeps a plain payment expense and older expenses of the bill',
      () async {
        await august();
        // Unlinked: the payment is plain spending (no bill id).
        await addBill(recurring: false);
        await payBill('rent');
        // An expense for this bill from an earlier day (e.g. while it was
        // recurring) is history, not part of this payment.
        await app.expenseRepository.createExpense(
          ExpenseEntity(
            id: 'earlier',
            budgetId: 'aug',
            amount: 12000,
            categoryId: 'bills',
            date: DateTime(2026, 8, 2),
            time: DateTime(2026, 8, 2, 10),
            createdAt: DateTime(2026, 8, 2),
            updatedAt: DateTime(2026, 8, 2),
            billId: 'rent',
          ),
        );

        final preview = await markUnpaid.expensesToRemove('rent');
        expect((preview as BillSuccess<List<ExpenseEntity>>).data, isEmpty);

        await markUnpaid('rent');

        expect((await expensesOf('aug')).length, 2);
        expect(await app.billRepository.getBillPayments('rent'), isEmpty);
      },
    );

    test('finds the payment expense after its date was edited (review: the '
        'paid-day lookup missed it and the bill was deducted twice)', () async {
      await august();
      await addBill(recurring: false, budgetId: 'aug');
      final outcome = paid(await payBill('rent'));
      // The user moves the expense to the day they actually paid. A
      // same-budget edit keeps bill_id (ExpenseForm builds a fresh entity).
      final edited = outcome.expense;
      await app.expenseRepository.updateExpense(
        ExpenseEntity(
          id: edited.id,
          budgetId: edited.budgetId,
          amount: edited.amount,
          categoryId: edited.categoryId,
          note: edited.note,
          date: DateTime(2026, 8, 9),
          time: DateTime(2026, 8, 9, 18),
          createdAt: DateTime(2026, 8, 11, 8),
          updatedAt: DateTime(2026, 8, 11, 8),
        ),
      );
      final stored = (await expensesOf('aug')).single;
      expect(stored.date, DateTime(2026, 8, 9));
      expect(stored.billId, 'rent');

      final preview = await markUnpaid.expensesToRemove('rent');
      expect(
        (preview as BillSuccess<List<ExpenseEntity>>).data.map((e) => e.id),
        [edited.id],
      );

      await markUnpaid('rent');

      expect(await expensesOf('aug'), isEmpty);
      expect(await app.storedRemaining('aug'), 30000);
    });

    test('a one-time bill that was recurring keeps the earlier occurrence\'s '
        'payment expense and deletes only this payment\'s', () async {
      await august();
      await addBill(budgetId: 'aug');
      // Paid while monthly (expense E1, createdAt = an earlier moment).
      final first = PayBillUseCase(
        billRepository: app.billRepository,
        budgetRepository: app.budgetRepository,
        expenseRepository: app.expenseRepository,
        clock: () => DateTime(2026, 8, 3, 9),
      );
      final e1 = paid(await first('rent')).expense;
      // Edited into a one-time bill, then paid again (E2, at `now`).
      final advanced = (await app.billRepository.getBillById('rent'))!;
      await app.billRepository.updateBill(
        advanced.copyWith(
          dueDate: DateTime(2026, 8, 15),
          isRecurring: false,
          recurrenceType: RecurrenceType.none,
        ),
      );
      // Valid data: E1 paid an earlier occurrence (its payment record is
      // still there), so the integrity check reports nothing.
      final integrity = DatabaseIntegrityService(database: app.database);
      expect(
        (await integrity.runFullCheck()).issues.where(
          (i) => i.entityId == 'rent',
        ),
        isEmpty,
      );
      final e2 = paid(await payBill('rent')).expense;

      final preview = await markUnpaid.expensesToRemove('rent');
      expect(
        (preview as BillSuccess<List<ExpenseEntity>>).data.map((e) => e.id),
        [e2.id],
      );

      await markUnpaid('rent');

      expect((await expensesOf('aug')).map((e) => e.id), [e1.id]);
    });

    test('nothing changes when the expense cannot be deleted', () async {
      await august();
      await addBill(recurring: false, budgetId: 'aug');
      await payBill('rent');
      final failing = MarkBillUnpaidUseCase(
        repository: app.billRepository,
        expenseRepository: _FailingDeleteExpenseRepository(app),
      );

      final result = await failing('rent');

      expect(result, isA<BillError<BillEntity>>());
      expect((await app.billRepository.getBillById('rent'))!.isPaid, isTrue);
      expect((await app.billRepository.getBillPayments('rent')).length, 1);
      expect((await expensesOf('aug')).length, 1);
    });
  });

  group('LinkBillsToBudgetUseCase', () {
    late LinkBillsToBudgetUseCase link;

    setUp(() {
      link = LinkBillsToBudgetUseCase(
        billRepository: app.billRepository,
        budgetRepository: app.budgetRepository,
        clock: () => DateTime(2026, 8, 10, 9),
      );
    });

    test('links every selected bill to the budget', () async {
      await august();
      await addBill(id: 'rent');
      await addBill(id: 'power', amount: 900);

      final result = await link(budgetId: 'aug', billIds: ['rent', 'power']);

      expect(
        (result as BillSuccess<List<BillEntity>>).data.map((b) => b.budgetId),
        ['aug', 'aug'],
      );
      expect((await app.billRepository.getBillById('rent'))!.budgetId, 'aug');
      expect((await app.billRepository.getBillById('power'))!.budgetId, 'aug');
      expect(
        (await app.billRepository.getBillById('rent'))!.updatedAt,
        DateTime(2026, 8, 10, 9),
      );
    });

    test('a bill in another currency links nothing', () async {
      await august();
      await addBill(id: 'rent');
      await addBill(id: 'netflix', amount: 10, currency: 'USD');

      final result = await link(budgetId: 'aug', billIds: ['rent', 'netflix']);

      expect(failed(result).type, BillErrorType.invalidInput);
      expect((await app.billRepository.getBillById('rent'))!.budgetId, isNull);
      expect(
        (await app.billRepository.getBillById('netflix'))!.budgetId,
        isNull,
      );
    });

    test('an archived or missing budget is notFound', () async {
      await august();
      await app.budgetRepository.setBudgetArchived('aug', archived: true);
      await addBill();

      expect(
        failed(await link(budgetId: 'aug', billIds: ['rent'])).type,
        BillErrorType.notFound,
      );
      expect(
        failed(await link(budgetId: 'gone', billIds: ['rent'])).type,
        BillErrorType.notFound,
      );
      expect((await app.billRepository.getBillById('rent'))!.budgetId, isNull);
    });
  });
}

/// Real expense storage that fails every delete.
class _FailingDeleteExpenseRepository extends ExpenseRepositoryImpl {
  _FailingDeleteExpenseRepository(AppHarness app)
    : super(
        localDataSource: ExpenseLocalDataSourceImpl(database: app.database),
        budgetRepository: app.budgetRepository,
      );

  @override
  Future<void> deleteExpense(String id) async => throw StateError('disk full');
}
