import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_failure.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/payment_allocation.dart';
import 'package:monivo/features/pay_later/domain/entities/purchase_change_impact.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_purchase_usecase.dart';

import '../../../helpers/in_memory_database.dart';
import '../../../helpers/pay_later_fixtures.dart';

/// The real Pay Later repository, made to fail on demand. [onFail] runs
/// just before the throw, so a test can look at what the transaction had
/// already written.
class _FlakyPayLaterRepository extends PayLaterRepositoryImpl {
  _FlakyPayLaterRepository(AppDatabase db)
    : super(localDataSource: PayLaterLocalDataSourceImpl(database: db));

  bool failLink = false;
  bool failReconcile = false;
  Future<void> Function()? onFail;

  /// When set, the [paymentsOf] read with this number (counted from when it
  /// was set, 1 first) throws: restore reads payments once itself, then
  /// its reconcile reads them again.
  int? failPaymentsOfCall;
  int _paymentsOfCalls = 0;

  @override
  Future<void> linkExpense({
    required String expenseId,
    required String tabId,
  }) async {
    if (failLink) {
      await onFail?.call();
      throw StateError('link write failed');
    }
    return super.linkExpense(expenseId: expenseId, tabId: tabId);
  }

  @override
  Future<List<TabPayment>> paymentsOf(String tabId) async {
    final failOn = failPaymentsOfCall;
    if (failOn != null && ++_paymentsOfCalls == failOn) {
      throw StateError('reconcile failed');
    }
    if (failReconcile) {
      await onFail?.call();
      throw StateError('reconcile failed');
    }
    return super.paymentsOf(tabId);
  }
}

void main() {
  late AppDatabase db;
  late BudgetRepositoryImpl budgets;
  late ExpenseRepositoryImpl expenses;
  late _FlakyPayLaterRepository payLater;
  late ReconcileTabUseCase reconcile;
  late TabPurchaseUseCase useCase;

  Future<void> seedBudget(String id, {String currency = 'OMR'}) => db
      .into(db.budgets)
      .insert(
        BudgetsCompanion.insert(
          id: id,
          name: id,
          monthlyAmount: 100,
          remainingAmount: 100,
          currency: currency,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await createInMemoryDatabase();
    budgets = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(
        database: db,
        sharedPreferences: await SharedPreferences.getInstance(),
      ),
      calculationService: BudgetCalculationService(),
    );
    expenses = ExpenseRepositoryImpl(
      localDataSource: ExpenseLocalDataSourceImpl(database: db),
      budgetRepository: budgets,
    );
    payLater = _FlakyPayLaterRepository(db);
    reconcile = ReconcileTabUseCase(repository: payLater);
    useCase = TabPurchaseUseCase(
      expenseRepository: expenses,
      budgetRepository: budgets,
      payLaterRepository: payLater,
      reconcileTab: reconcile,
    );
    await seedPayLaterBudget(db); // b1, OMR, 100
    await seedBudget('b2');
    await seedBudget('inr', currency: 'INR');
    await payLater.createTab(payLaterTab('t1'));
    await payLater.createTab(payLaterTab('t2', name: 'Shop'));
    await payLater.createTab(payLaterTab('tInr', currency: 'INR'));
    await payLater.createTab(
      payLaterTab('old', name: 'Old').copyWith(isArchived: true),
    );
  });

  tearDown(() => db.close());

  Future<double> remaining(String budgetId) async =>
      (await budgets.getBudgetById(budgetId))!.remainingAmount;

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
          .read<int>('c');

  /// A purchase at [hour] o'clock on 1 Nov, so FIFO order is by hour.
  ExpenseEntity purchase(String id, double amount, {int hour = 12}) =>
      payLaterExpense(
        id,
        amount: amount,
      ).copyWith(time: DateTime(2026, 11, 1, hour));

  Future<void> addPayment(String id, String tabId, double amount) async {
    await payLater.createPayment(
      TabPayment(
        id: id,
        tabId: tabId,
        amount: amount,
        paidDate: DateTime(2026, 11, 2),
        createdAt: payLaterStamp,
        updatedAt: payLaterStamp,
      ),
    );
    await payLater.transaction(() => reconcile(tabId));
  }

  Future<List<(String, String, double)>> allocations(String tabId) async => [
    for (final a in await payLater.allocationsOf(tabId))
      (a.paymentId, a.expenseId, a.amount),
  ]..sort((a, b) => '${a.$1}${a.$2}'.compareTo('${b.$1}${b.$2}'));

  Future<void> addOnTab(ExpenseEntity expense, String tabId) async {
    final result = await useCase.create(expense, tabId: tabId);
    expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
  }

  ExpenseFailure failureOf(ExpenseResult<Object?> result) =>
      (result as ExpenseError).failure;

  group('create', () {
    test(
      'create writes expense and link together; a failing link write leaves no expense',
      () async {
        final result = await useCase.create(purchase('e1', 10), tabId: 't1');

        expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
        expect(await expenses.getExpenseById('e1'), isNotNull);
        expect(await payLater.tabIdForExpense('e1'), 't1');
        expect(await remaining('b1'), 90);

        payLater.failLink = true;
        final failed = await useCase.create(purchase('e2', 5), tabId: 't1');

        expect(failureOf(failed).type, ExpenseErrorType.databaseFailure);
        expect(await expenses.getExpenseById('e2'), isNull);
        expect(await payLater.tabIdForExpense('e2'), isNull);
        expect(await remaining('b1'), 90);
      },
    );

    test(
      'failed link insert rolls back expense and budget remaining',
      () async {
        double? remainingWhenLinkFailed;
        ExpenseEntity? expenseWhenLinkFailed;
        payLater
          ..failLink = true
          ..onFail = () async {
            remainingWhenLinkFailed = await remaining('b1');
            expenseWhenLinkFailed = await expenses.getExpenseById('e1');
          };

        final result = await useCase.create(purchase('e1', 10), tabId: 't1');

        // The expense insert and the budget update had run inside the
        // transaction when the link write failed...
        expect(expenseWhenLinkFailed, isNotNull);
        expect(remainingWhenLinkFailed, 90);
        // ...and all of it rolled back.
        expect(failureOf(result).type, ExpenseErrorType.databaseFailure);
        expect(await expenses.getExpenseById('e1'), isNull);
        expect(await count('expenses'), 0);
        expect(await remaining('b1'), 100);
        expect(await count('pay_later_entries'), 0);
      },
    );

    test('create rejects a tab in another currency', () async {
      final result = await useCase.create(purchase('e1', 10), tabId: 'tInr');

      final failure = failureOf(result);
      expect(failure.type, ExpenseErrorType.invalidInput);
      expect(failure.message, 'This tab is in INR. Pick a budget in INR.');
      expect(await count('expenses'), 0);
      expect(await count('pay_later_entries'), 0);
      expect(await remaining('b1'), 100);
    });

    test('create rejects an archived tab', () async {
      final result = await useCase.create(purchase('e1', 10), tabId: 'old');

      expect(failureOf(result).type, ExpenseErrorType.invalidInput);
      expect(await count('expenses'), 0);
      expect(await count('pay_later_entries'), 0);
      expect(await remaining('b1'), 100);
    });

    test('create rejects a missing tab and an invalid expense', () async {
      final missing = await useCase.create(purchase('e1', 10), tabId: 'nope');
      expect(failureOf(missing).type, ExpenseErrorType.notFound);

      final invalid = await useCase.create(purchase('e1', 0), tabId: 't1');
      expect(failureOf(invalid).type, ExpenseErrorType.invalidInput);

      expect(await count('expenses'), 0);
      expect(await count('pay_later_entries'), 0);
    });

    test('create applies the tab credit to the new purchase', () async {
      await addPayment('p1', 't1', 4);

      await addOnTab(purchase('e1', 10), 't1');

      expect(await allocations('t1'), [('p1', 'e1', 4.0)]);
    });

    test(
      'create rejects a bill payment, with no expense row written',
      () async {
        final result = await useCase.create(
          purchase('e1', 10).copyWith(billId: 'bill1'),
          tabId: 't1',
        );

        final failure = failureOf(result);
        expect(failure.type, ExpenseErrorType.invalidInput);
        expect(failure.message, "A bill payment can't go on a Pay later tab.");
        expect(await count('expenses'), 0);
        expect(await count('pay_later_entries'), 0);
        expect(await remaining('b1'), 100);
      },
    );
  });

  group('update', () {
    test(
      "failed reconcile on update rolls back the expense edit, both budgets' remaining and the link move",
      () async {
        await addOnTab(purchase('e1', 10), 't1');
        String? linkWhenReconcileFailed;
        double? b2WhenReconcileFailed;
        payLater
          ..failReconcile = true
          ..onFail = () async {
            linkWhenReconcileFailed = await payLater.tabIdForExpense('e1');
            b2WhenReconcileFailed = await remaining('b2');
          };

        final result = await useCase.update(
          purchase('e1', 7).copyWith(budgetId: 'b2'),
          tabId: 't2',
        );

        // The edit, both budgets and the link move had been written...
        expect(linkWhenReconcileFailed, 't2');
        expect(b2WhenReconcileFailed, 93);
        // ...and all of it rolled back.
        expect(failureOf(result).type, ExpenseErrorType.databaseFailure);
        final stored = await expenses.getExpenseById('e1');
        expect(stored!.amount, 10);
        expect(stored.budgetId, 'b1');
        expect(await remaining('b1'), 90);
        expect(await remaining('b2'), 100);
        expect(await payLater.tabIdForExpense('e1'), 't1');
      },
    );

    test('update moving between tabs reconciles both', () async {
      await addOnTab(purchase('e1', 5), 't1');
      await addPayment('p1', 't1', 5);
      await addPayment('p2', 't2', 4); // credit on t2
      expect(await allocations('t1'), [('p1', 'e1', 5.0)]);

      final result = await useCase.update(purchase('e1', 5), tabId: 't2');

      expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
      expect(await payLater.tabIdForExpense('e1'), 't2');
      // t1: p1 is credit now; t2: its credit pays the purchase.
      expect(await allocations('t1'), isEmpty);
      expect(await allocations('t2'), [('p2', 'e1', 4.0)]);
      expect(await remaining('b1'), 95);
    });

    test('update turning pay later off unlinks and reconciles', () async {
      await addOnTab(purchase('e1', 5, hour: 12), 't1');
      await addOnTab(purchase('e2', 8, hour: 13), 't1');
      await addPayment('p1', 't1', 6);
      expect(await allocations('t1'), [('p1', 'e1', 5.0), ('p1', 'e2', 1.0)]);

      final result = await useCase.update(purchase('e1', 5), tabId: null);

      expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
      expect(await payLater.tabIdForExpense('e1'), isNull);
      expect(await expenses.getExpenseById('e1'), isNotNull);
      expect(await allocations('t1'), [('p1', 'e2', 6.0)]);
      expect(await remaining('b1'), 87);
    });

    test('update lowering a paid purchase frees money FIFO', () async {
      await addOnTab(purchase('e1', 5, hour: 12), 't1');
      await addOnTab(purchase('e2', 8, hour: 13), 't1');
      await addPayment('p1', 't1', 5);

      final result = await useCase.update(purchase('e1', 2), tabId: 't1');

      expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
      expect(await allocations('t1'), [('p1', 'e1', 2.0), ('p1', 'e2', 3.0)]);
      expect(await remaining('b1'), 90);
    });

    test('update rejects a budget in another currency', () async {
      await addOnTab(purchase('e1', 5), 't1');

      final result = await useCase.update(
        purchase('e1', 5).copyWith(budgetId: 'inr'),
        tabId: 't1',
      );

      expect(failureOf(result).type, ExpenseErrorType.invalidInput);
      expect((await expenses.getExpenseById('e1'))!.budgetId, 'b1');
    });

    test('update keeps a purchase on its archived tab but cannot move one '
        'onto an archived tab', () async {
      await addOnTab(purchase('e1', 5), 't1');
      await payLater.updateTab(
        (await payLater.getTab('t1'))!.copyWith(isArchived: true),
      );

      final kept = await useCase.update(purchase('e1', 6), tabId: 't1');
      expect(kept, isA<ExpenseSuccess<ExpenseEntity>>());

      final moved = await useCase.update(purchase('e1', 6), tabId: 'old');
      expect(failureOf(moved).type, ExpenseErrorType.invalidInput);
      expect(await payLater.tabIdForExpense('e1'), 't1');
    });

    test('update of a missing expense is notFound', () async {
      final result = await useCase.update(purchase('ghost', 5), tabId: 't1');
      expect(failureOf(result).type, ExpenseErrorType.notFound);
    });

    test('update linking a bill payment is rejected, and the stored expense is '
        'unchanged', () async {
      final bill = purchase('e1', 10).copyWith(billId: 'bill1');
      await expenses.createExpense(bill);

      final result = await useCase.update(
        bill.copyWith(amount: 7),
        tabId: 't1',
      );

      final failure = failureOf(result);
      expect(failure.type, ExpenseErrorType.invalidInput);
      expect(failure.message, "A bill payment can't go on a Pay later tab.");
      expect(await expenses.getExpenseById('e1'), bill);
      expect(await payLater.tabIdForExpense('e1'), isNull);
      expect(await remaining('b1'), 90);
    });

    test('update linking a stored bill payment is rejected even when the edit '
        'drops billId', () async {
      final bill = purchase('e1', 10).copyWith(billId: 'bill1');
      await expenses.createExpense(bill);

      // Same budget, so the expense repository would keep the stored
      // bill_id; a form builds the entity without it.
      final result = await useCase.update(
        bill.copyWith(clearBillId: true, amount: 7),
        tabId: 't1',
      );

      final failure = failureOf(result);
      expect(failure.type, ExpenseErrorType.invalidInput);
      expect(failure.message, "A bill payment can't go on a Pay later tab.");
      expect(await payLater.tabIdForExpense('e1'), isNull);
      expect(await count('pay_later_entries'), 0);
      final stored = (await expenses.getExpenseById('e1'))!;
      expect(stored, bill);
      expect(stored.billId, 'bill1');
      expect(stored.amount, 10);
      expect(await remaining('b1'), 90);
    });

    test('update of a bill payment with tabId: null succeeds', () async {
      final bill = purchase('e1', 10).copyWith(billId: 'bill1');
      await expenses.createExpense(bill);
      final edited = bill.copyWith(amount: 7, note: 'Bill: Internet');

      final result = await useCase.update(edited, tabId: null);

      expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
      expect(await expenses.getExpenseById('e1'), edited);
      expect((await expenses.getExpenseById('e1'))!.billId, 'bill1');
      expect(await payLater.tabIdForExpense('e1'), isNull);
      expect(await remaining('b1'), 93);
    });
  });

  group('delete and restore', () {
    test(
      'delete returns the snapshot and undo restores link and allocations',
      () async {
        await addOnTab(purchase('e1', 5, hour: 12), 't1');
        await addOnTab(purchase('e2', 8, hour: 13), 't1');
        await addPayment('p1', 't1', 6);
        final e1Row = (await payLater.allocationsOf(
          't1',
        )).singleWhere((a) => a.expenseId == 'e1');
        final e1 = (await expenses.getExpenseById('e1'))!;

        final deleted = await useCase.delete('e1');

        final snapshot = (deleted as ExpenseSuccess<TabLinkSnapshot?>).data!;
        expect(snapshot.tabId, 't1');
        expect(snapshot.allocations, [e1Row]);
        expect(await expenses.getExpenseById('e1'), isNull);
        expect(await remaining('b1'), 92);
        expect(await allocations('t1'), [('p1', 'e2', 6.0)]);

        final restored = await useCase.restore(e1, snapshot);

        expect(restored, isA<ExpenseSuccess<ExpenseEntity>>());
        expect(await expenses.getExpenseById('e1'), e1);
        expect(await remaining('b1'), 87);
        expect(await payLater.tabIdForExpense('e1'), 't1');
        expect(await allocations('t1'), [('p1', 'e1', 5.0), ('p1', 'e2', 1.0)]);
        // The same allocation row is back, not a lookalike.
        expect(
          (await payLater.allocationsOf(
            't1',
          )).singleWhere((a) => a.expenseId == 'e1'),
          e1Row,
        );
      },
    );

    test('restore drops allocations of a deleted payment', () async {
      await addOnTab(purchase('e1', 5, hour: 12), 't1');
      await addPayment('p1', 't1', 3);
      await addPayment('p2', 't1', 2);
      final e1 = (await expenses.getExpenseById('e1'))!;
      final snapshot =
          ((await useCase.delete('e1')) as ExpenseSuccess<TabLinkSnapshot?>)
              .data!;
      expect(snapshot.allocations, hasLength(2));
      await payLater.deletePayment('p2');

      final restored = await useCase.restore(e1, snapshot);

      expect(restored, isA<ExpenseSuccess<ExpenseEntity>>());
      expect(await allocations('t1'), [('p1', 'e1', 3.0)]);
    });

    test('delete of a plain expense returns no snapshot; restore without one '
        'is a plain expense', () async {
      await expenses.createExpense(purchase('e1', 5));

      final deleted = await useCase.delete('e1');

      expect((deleted as ExpenseSuccess<TabLinkSnapshot?>).data, isNull);
      expect(await remaining('b1'), 100);

      final restored = await useCase.restore(purchase('e1', 5), null);

      expect(restored, isA<ExpenseSuccess<ExpenseEntity>>());
      expect(await remaining('b1'), 95);
      expect(await payLater.tabIdForExpense('e1'), isNull);
    });

    test(
      'a reconcile that fails inside restore puts nothing back (T6)',
      () async {
        await addOnTab(purchase('e1', 5), 't1');
        await addPayment('p1', 't1', 3);
        final e1 = (await expenses.getExpenseById('e1'))!;
        final snapshot =
            ((await useCase.delete('e1')) as ExpenseSuccess<TabLinkSnapshot?>)
                .data!;
        expect(snapshot.allocations, hasLength(1));
        // Restore's own read is call 1; its reconcile's read is call 2.
        payLater.failPaymentsOfCall = 2;

        final restored = await useCase.restore(e1, snapshot);

        expect(failureOf(restored).type, ExpenseErrorType.databaseFailure);
        expect(await expenses.getExpenseById('e1'), isNull);
        expect(await payLater.tabIdForExpense('e1'), isNull);
        expect(await allocations('t1'), isEmpty);
        expect(await remaining('b1'), 100);
      },
    );

    test('restore after its tab was deleted gives back a plain expense '
        '(T6)', () async {
      await addOnTab(purchase('e1', 5), 't2');
      final e1 = (await expenses.getExpenseById('e1'))!;
      final snapshot =
          ((await useCase.delete('e1')) as ExpenseSuccess<TabLinkSnapshot?>)
              .data!;
      expect(snapshot.tabId, 't2');
      await payLater.deleteTab('t2');

      final restored = await useCase.restore(e1, snapshot);

      expect(restored, isA<ExpenseSuccess<ExpenseEntity>>());
      expect(await expenses.getExpenseById('e1'), e1);
      expect(await payLater.tabIdForExpense('e1'), isNull);
      expect(await remaining('b1'), 95);
    });

    test('delete of a missing expense is notFound', () async {
      final result = await useCase.delete('ghost');
      expect(failureOf(result).type, ExpenseErrorType.notFound);
    });

    test('a failed reconcile on delete keeps the purchase', () async {
      await addOnTab(purchase('e1', 5), 't1');
      payLater.failReconcile = true;

      final result = await useCase.delete('e1');

      expect(failureOf(result).type, ExpenseErrorType.databaseFailure);
      expect(await expenses.getExpenseById('e1'), isNotNull);
      expect(await payLater.tabIdForExpense('e1'), 't1');
      expect(await remaining('b1'), 95);
    });
  });

  group('impactOf', () {
    test(
      'impactOf deleting a paid purchase names where the money goes',
      () async {
        await addOnTab(purchase('e1', 5, hour: 12), 't1');
        await addOnTab(purchase('e2', 2, hour: 13), 't1');
        await addPayment('p1', 't1', 6);
        final before = await allocations('t1');
        final e2 = (await expenses.getExpenseById('e2'))!;

        final impact = await useCase.impactOf('e1', deleting: true);

        expect(
          impact,
          PurchaseChangeImpact(
            paidOnIt: 5,
            movesTo: [(e2, 1.0)],
            becomesCredit: 4,
            currency: 'OMR',
          ),
        );
        expect(impact!.touchesPayments, isTrue);
        // A dry run: nothing written.
        expect(await allocations('t1'), before);
        expect(await expenses.getExpenseById('e1'), isNotNull);
      },
    );

    test('impactOf an edit counts only the money it takes off', () async {
      await addOnTab(purchase('e1', 5, hour: 12), 't1');
      await addOnTab(purchase('e2', 8, hour: 13), 't1');
      await addPayment('p1', 't1', 5);
      final e2 = (await expenses.getExpenseById('e2'))!;

      final lower = await useCase.impactOf('e1', newAmount: 2, newTabId: 't1');
      expect(lower!.paidOnIt, 3);
      expect(lower.movesTo, [(e2, 3.0)]);
      expect(lower.becomesCredit, 0);
      // QA F3: the dialog says 5 was paid and 2 of it stays.
      expect(lower.paidBefore, 5);

      final higher = await useCase.impactOf('e1', newAmount: 9, newTabId: 't1');
      expect(higher!.touchesPayments, isFalse);
      expect(higher.movesTo, isEmpty);

      final moved = await useCase.impactOf('e1', newTabId: 't2');
      expect(moved!.paidOnIt, 5);
      expect(moved.paidBefore, 5);
      expect(moved.movesTo, [(e2, 5.0)]);

      final turnedOff = await useCase.impactOf('e1', newAmount: 5);
      expect(turnedOff!.paidOnIt, 5);
    });

    test('impactOf a purchase that is not on a tab is null', () async {
      await expenses.createExpense(purchase('e1', 5));
      expect(await useCase.impactOf('e1', deleting: true), isNull);
      expect(await useCase.impactOf('ghost', deleting: true), isNull);
    });
  });

  test('tabIdFor and tabInfoFor read the link and what was paid', () async {
    await addOnTab(purchase('e1', 5, hour: 12), 't1');
    await addOnTab(purchase('e2', 8, hour: 13), 't1');
    await addPayment('p1', 't1', 6);
    await expenses.createExpense(purchase('plain', 1));

    expect(await useCase.tabIdFor('e2'), 't1');
    expect(await useCase.tabIdFor('plain'), isNull);
    final info = await useCase.tabInfoFor('e2');
    expect(info!.tab.id, 't1');
    expect(info.paid, 1);
    expect(await useCase.tabInfoFor('plain'), isNull);
  });

  test('a snapshot is value-equal', () {
    final row = PaymentAllocation(
      id: 'a',
      paymentId: 'p',
      expenseId: 'e',
      amount: 1,
      isManual: false,
      createdAt: payLaterStamp,
    );
    expect(
      TabLinkSnapshot(tabId: 't', allocations: [row]),
      TabLinkSnapshot(tabId: 't', allocations: [row]),
    );
  });
}
