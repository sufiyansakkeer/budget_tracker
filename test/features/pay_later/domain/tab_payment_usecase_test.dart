import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/currency/money_math.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_allocator.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_ledger.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_payment_usecase.dart';

import '../../../helpers/in_memory_database.dart';
import '../../../helpers/pay_later_fixtures.dart';

/// The real Pay Later repository, made to fail on demand.
class _FlakyPayLaterRepository extends PayLaterRepositoryImpl {
  _FlakyPayLaterRepository(AppDatabase db)
    : super(localDataSource: PayLaterLocalDataSourceImpl(database: db));

  /// [applyDiff] throws (after [onFail]) instead of writing.
  bool failApplyDiff = false;
  Future<void> Function()? onFail;

  /// The next [getPayment] answers null, as if another writer had not
  /// committed yet when it was read (the primary-key fallback path).
  bool hideNextGetPayment = false;

  @override
  Future<void> applyDiff(AllocationDiff diff) async {
    if (failApplyDiff) {
      await onFail?.call();
      throw StateError('allocation write failed');
    }
    return super.applyDiff(diff);
  }

  @override
  Future<TabPayment?> getPayment(String id) async {
    if (hideNextGetPayment) {
      hideNextGetPayment = false;
      return null;
    }
    return super.getPayment(id);
  }
}

void main() {
  late AppDatabase db;
  late _FlakyPayLaterRepository payLater;
  late TabPaymentUseCase useCase;

  /// 2 Nov 2026, 10:00: purchases are on 1 Nov.
  final now = DateTime(2026, 11, 2, 10);
  final today = DateTime(2026, 11, 2);

  setUp(() async {
    db = await createInMemoryDatabase();
    payLater = _FlakyPayLaterRepository(db);
    useCase = TabPaymentUseCase(
      repository: payLater,
      reconcileTab: ReconcileTabUseCase(repository: payLater),
      clock: () => now,
    );
    await seedPayLaterBudget(db); // b1, OMR
    await payLater.createTab(payLaterTab('t1'));
    await payLater.createTab(payLaterTab('t2', name: 'Shop'));
  });

  tearDown(() => db.close());

  final money = MoneyMath.forCurrency('OMR');

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
          .read<int>('c');

  /// A purchase on [tabId] at [hour] o'clock on 1 Nov (FIFO is by hour).
  Future<void> addPurchase(
    String id,
    double amount, {
    int hour = 12,
    String tabId = 't1',
  }) async {
    final ExpenseEntity expense = payLaterExpense(
      id,
      amount: amount,
    ).copyWith(time: DateTime(2026, 11, 1, hour));
    await addPayLaterExpense(db, expense);
    await payLater.linkExpense(expenseId: id, tabId: tabId);
  }

  Future<({double owed, double credit})> balance(String tabId) async {
    final ledger = PayLaterLedger.build(
      tab: (await payLater.getTab(tabId))!,
      purchases: await payLater.purchasesOf(tabId),
      payments: await payLater.paymentsOf(tabId),
      allocations: await payLater.allocationsOf(tabId),
      today: today,
    );
    return (owed: ledger.owed, credit: ledger.credit);
  }

  /// Units paid on each purchase of [tabId].
  Future<Map<String, int>> paidOn(String tabId) async {
    final paid = <String, int>{};
    for (final a in await payLater.allocationsOf(tabId)) {
      paid.update(
        a.expenseId,
        (v) => v + money.toUnits(a.amount),
        ifAbsent: () => money.toUnits(a.amount),
      );
    }
    return paid;
  }

  Future<PayLaterResult<TabPayment>> record(
    String id,
    double amount, {
    String tabId = 't1',
    DateTime? paidDate,
    Set<String> chosen = const {},
    String? note,
  }) => useCase.record(
    paymentId: id,
    tabId: tabId,
    amount: amount,
    paidDate: paidDate ?? today,
    note: note,
    chosenExpenseIds: chosen,
  );

  TabPayment paymentOf(PayLaterResult<TabPayment> result) =>
      (result as PayLaterSuccess<TabPayment>).data;

  PayLaterFailure failureOf(PayLaterResult<Object?> result) =>
      (result as PayLaterError).failure;

  group('record', () {
    test('settle all leaves owed 0', () async {
      await addPurchase('e1', 3, hour: 9);
      await addPurchase('e2', 2.5, hour: 13);

      final result = await record('p1', 5.5);

      expect(paymentOf(result).amount, 5.5);
      expect((await balance('t1')).owed, 0);
      expect((await balance('t1')).credit, 0);
      expect(await paidOn('t1'), {'e1': 3000, 'e2': 2500});
    });

    test('partial then second payment', () async {
      await addPurchase('e1', 3, hour: 9);
      await addPurchase('e2', 2, hour: 13);

      expect(await record('p1', 2), isA<PayLaterSuccess<TabPayment>>());
      expect((await balance('t1')).owed, 3);
      // FIFO: the oldest purchase is paid first.
      expect(await paidOn('t1'), {'e1': 2000});

      expect(await record('p2', 3), isA<PayLaterSuccess<TabPayment>>());
      expect((await balance('t1')).owed, 0);
      expect(await paidOn('t1'), {'e1': 3000, 'e2': 2000});
      expect(await count('pay_later_payments'), 2);
    });

    test('overpay rejected', () async {
      await addPurchase('e1', 3);

      final result = await record('p1', 3.001);

      expect(failureOf(result).type, PayLaterErrorType.invalidInput);
      expect(await count('pay_later_payments'), 0);
      expect(await count('pay_later_allocations'), 0);
      expect((await balance('t1')).owed, 3);
    });

    test('an amount equal to owed after rounding is accepted', () async {
      await addPurchase('e1', 3);

      // 3.0004 rounds to 3.000 at OMR's 3 decimals.
      final result = await record('p1', 3.0004);

      expect(paymentOf(result).amount, 3);
      expect((await balance('t1')).owed, 0);
    });

    test('zero, negative and non-finite amounts are rejected', () async {
      await addPurchase('e1', 3);

      for (final amount in [0.0, -1.0, 0.0004, double.nan, double.infinity]) {
        final result = await record('p-$amount', amount);
        expect(
          failureOf(result).type,
          PayLaterErrorType.invalidInput,
          reason: '$amount',
        );
      }
      expect(await count('pay_later_payments'), 0);
    });

    test(
      'a paid date after today is rejected; today and earlier are not',
      () async {
        await addPurchase('e1', 3);

        final future = await record('p1', 1, paidDate: DateTime(2026, 11, 3));
        expect(failureOf(future).type, PayLaterErrorType.invalidInput);

        // Later today (a time after the clock) is still today.
        expect(
          await record('p2', 1, paidDate: DateTime(2026, 11, 2, 23, 59)),
          isA<PayLaterSuccess<TabPayment>>(),
        );
        expect(
          await record('p3', 1, paidDate: DateTime(2026, 10, 20)),
          isA<PayLaterSuccess<TabPayment>>(),
        );
        expect(await count('pay_later_payments'), 2);
      },
    );

    test('a missing tab is notFound', () async {
      final result = await record('p1', 1, tabId: 'nope');

      expect(failureOf(result).type, PayLaterErrorType.notFound);
      expect(await count('pay_later_payments'), 0);
    });

    test('chosen purchases paid first', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 11);
      await addPurchase('e3', 4, hour: 13);

      // 5 = e3 (chosen, 4) + 1 left over, which goes FIFO to e1.
      final result = await record('p1', 5, chosen: {'e3'});

      expect(result, isA<PayLaterSuccess<TabPayment>>());
      expect(await paidOn('t1'), {'e3': 4000, 'e1': 1000});
      final rows = await payLater.allocationsOf('t1');
      expect(rows.singleWhere((a) => a.expenseId == 'e3').isManual, isTrue);
      expect(rows.singleWhere((a) => a.expenseId == 'e1').isManual, isFalse);
      // 9 bought − 5 paid.
      expect((await balance('t1')).owed, 4);
      expect((await balance('t1')).credit, 0);
    });

    test('a chosen purchase that is not on this tab is rejected', () async {
      await addPurchase('e1', 2);
      await addPurchase('other', 2, tabId: 't2');

      final result = await record('p1', 1, chosen: {'other'});

      expect(failureOf(result).type, PayLaterErrorType.invalidInput);
      expect(await count('pay_later_payments'), 0);
    });

    test('transaction rolls back when allocation write fails', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 13);
      TabPayment? paymentWhenWriteFailed;
      payLater
        ..failApplyDiff = true
        ..onFail = () async {
          paymentWhenWriteFailed = await payLater.getPayment('p1');
        };

      final result = await record('p1', 4, chosen: {'e2'});

      // The payment insert had run inside the transaction...
      expect(paymentWhenWriteFailed, isNotNull);
      // ...and rolled back with the failed allocation write.
      expect(failureOf(result).type, PayLaterErrorType.databaseFailure);
      expect(await payLater.getPayment('p1'), isNull);
      expect(await count('pay_later_payments'), 0);
      expect(await count('pay_later_allocations'), 0);
      expect((await balance('t1')).owed, 5);

      // The same id can be recorded once the write works again.
      payLater.failApplyDiff = false;
      expect(
        await record('p1', 4, chosen: {'e2'}),
        isA<PayLaterSuccess<TabPayment>>(),
      );
      expect((await balance('t1')).owed, 1);
    });

    test('same payment id twice records one payment', () async {
      await addPurchase('e1', 5);

      final first = await record('p1', 2, note: 'cash');
      final second = await record('p1', 2, note: 'cash');

      expect(paymentOf(second), paymentOf(first));
      expect(await count('pay_later_payments'), 1);
      expect((await balance('t1')).owed, 3);
    });

    test('a repeat with the same id returns the stored payment unchanged, '
        'without checking the new values', () async {
      await addPurchase('e1', 5);
      await record('p1', 5);

      // Owed is 0 now, so a fresh payment would be an overpay.
      final again = await record('p1', 5);

      expect(paymentOf(again).amount, 5);
      expect(await count('pay_later_payments'), 1);
      expect((await balance('t1')).owed, 0);
    });

    test('a payment id already used on another tab is rejected', () async {
      await addPurchase('e1', 5);
      await addPurchase('e2', 5, tabId: 't2');
      await record('p1', 2);

      final result = await record('p1', 2, tabId: 't2');

      expect(failureOf(result).type, PayLaterErrorType.invalidInput);
      expect(await count('pay_later_payments'), 1);
      expect((await balance('t2')).owed, 5);
    });

    test('same payment id concurrently records one payment', () async {
      await addPurchase('e1', 5);

      final results = await Future.wait([record('p1', 2), record('p1', 2)]);

      expect(results, everyElement(isA<PayLaterSuccess<TabPayment>>()));
      expect(paymentOf(results[0]).id, 'p1');
      expect(paymentOf(results[1]).id, 'p1');
      expect(await count('pay_later_payments'), 1);
      expect((await balance('t1')).owed, 3);
    });

    test(
      'two concurrent payments of the full owed amount: one succeeds, one is rejected as overpay',
      () async {
        await addPurchase('e1', 2, hour: 9);
        await addPurchase('e2', 3, hour: 13);

        final results = await Future.wait([record('p1', 5), record('p2', 5)]);

        expect(results.whereType<PayLaterSuccess<TabPayment>>(), hasLength(1));
        final errors = results.whereType<PayLaterError<TabPayment>>().toList();
        expect(errors, hasLength(1));
        expect(errors.single.failure.type, PayLaterErrorType.invalidInput);
        expect((await balance('t1')).owed, 0);
        expect((await balance('t1')).credit, 0);
        expect(await count('pay_later_payments'), 1);
      },
    );

    test(
      'a primary-key clash on insert resolves to the stored payment',
      () async {
        await addPurchase('e1', 5);
        await record('p1', 2);
        // The idempotency read misses the row, so the insert hits the
        // primary key.
        payLater.hideNextGetPayment = true;

        final again = await record('p1', 2);

        expect(paymentOf(again).id, 'p1');
        expect(await count('pay_later_payments'), 1);
        expect((await balance('t1')).owed, 3);
      },
    );
  });

  group('update', () {
    Future<TabPayment> stored(String id) async =>
        (await payLater.getPayment(id))!;

    test('edit amount down trims the newest purchase first', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 13);
      await record('p1', 5);

      final result = await useCase.update(
        (await stored('p1')).copyWith(amount: 3),
      );

      expect(paymentOf(result).amount, 3);
      expect((await stored('p1')).amount, 3);
      expect(await paidOn('t1'), {'e1': 2000, 'e2': 1000});
      expect((await balance('t1')).owed, 2);
    });

    test('a failed reconcile rolls the edit back (T7)', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 13);
      await record('p1', 5);
      TabPayment? paymentWhenWriteFailed;
      payLater
        ..failApplyDiff = true
        ..onFail = () async {
          paymentWhenWriteFailed = await payLater.getPayment('p1');
        };

      final result = await useCase.update(
        (await stored('p1')).copyWith(amount: 3),
      );

      // The new amount had been written inside the transaction...
      expect(paymentWhenWriteFailed?.amount, 3);
      // ...and rolled back with the failed allocation write.
      expect(failureOf(result).type, PayLaterErrorType.databaseFailure);
      expect((await stored('p1')).amount, 5);
      expect(await paidOn('t1'), {'e1': 2000, 'e2': 3000});
      expect((await balance('t1')).owed, 0);
    });

    test('edit amount up applies the extra FIFO', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 13);
      await record('p1', 1);

      final result = await useCase.update(
        (await stored('p1')).copyWith(amount: 4),
      );

      expect(result, isA<PayLaterSuccess<TabPayment>>());
      expect(await paidOn('t1'), {'e1': 2000, 'e2': 2000});
      expect((await balance('t1')).owed, 1);
    });

    test('edit amount up to owed + this payment applied is accepted; above '
        'is rejected', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 13);
      await record('p1', 1);
      await record('p2', 1);

      // owed 3 + p1's applied 1 = 4.
      final over = await useCase.update(
        (await stored('p1')).copyWith(amount: 4.001),
      );
      expect(failureOf(over).type, PayLaterErrorType.invalidInput);
      expect((await stored('p1')).amount, 1);
      expect((await balance('t1')).owed, 3);

      final exact = await useCase.update(
        (await stored('p1')).copyWith(amount: 4),
      );
      expect(exact, isA<PayLaterSuccess<TabPayment>>());
      expect((await balance('t1')).owed, 0);
    });

    test('note and date only change no allocation, even for a payment in '
        'credit', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 13);
      await record('p1', 5);
      // e2 leaves the tab: 3 of p1 becomes credit.
      await payLater.transaction(() async {
        await payLater.unlinkExpense('e2');
        await ReconcileTabUseCase(repository: payLater)('t1');
      });
      expect((await balance('t1')).credit, 3);
      final before = await payLater.allocationsOf('t1');

      final result = await useCase.update(
        (await stored('p1')).copyWith(
          note: 'paid at the counter',
          paidDate: DateTime(2026, 11, 1),
        ),
      );

      expect(result, isA<PayLaterSuccess<TabPayment>>());
      final saved = await stored('p1');
      expect(saved.note, 'paid at the counter');
      expect(saved.paidDate, DateTime(2026, 11, 1));
      expect(saved.updatedAt, now);
      expect(await payLater.allocationsOf('t1'), before);
    });

    test('rejects zero amount, a future date and a missing payment', () async {
      await addPurchase('e1', 5);
      await record('p1', 2);

      final zero = await useCase.update(
        (await stored('p1')).copyWith(amount: 0),
      );
      expect(failureOf(zero).type, PayLaterErrorType.invalidInput);

      final future = await useCase.update(
        (await stored('p1')).copyWith(paidDate: DateTime(2026, 11, 3)),
      );
      expect(failureOf(future).type, PayLaterErrorType.invalidInput);

      final missing = await useCase.update(
        TabPayment(
          id: 'nope',
          tabId: 't1',
          amount: 1,
          paidDate: today,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(failureOf(missing).type, PayLaterErrorType.notFound);
      expect(await stored('p1'), isNot(null));
      expect((await stored('p1')).amount, 2);
      expect(await count('pay_later_payments'), 1);
    });

    test('a payment cannot move to another tab', () async {
      await addPurchase('e1', 5);
      await addPurchase('e2', 5, tabId: 't2');
      await record('p1', 2);
      final p1 = await stored('p1');

      final result = await useCase.update(
        TabPayment(
          id: p1.id,
          tabId: 't2',
          amount: p1.amount,
          paidDate: p1.paidDate,
          createdAt: p1.createdAt,
          updatedAt: p1.updatedAt,
        ),
      );

      expect(failureOf(result).type, PayLaterErrorType.invalidInput);
      expect((await stored('p1')).tabId, 't1');
      expect((await balance('t2')).owed, 5);
    });
  });

  group('delete', () {
    test('delete makes purchases owe again', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 13);
      await record('p1', 5);
      expect((await balance('t1')).owed, 0);

      final result = await useCase.delete('p1');

      expect(result, isA<PayLaterSuccess<void>>());
      expect(await payLater.getPayment('p1'), isNull);
      expect(await count('pay_later_allocations'), 0);
      expect((await balance('t1')).owed, 5);
    });

    test('deleting a payment lets credit from another payment cover the '
        'freed purchases', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 13);
      await record('p1', 2);
      await record('p2', 3);
      // e2 leaves the tab: p2's 3 becomes credit.
      await payLater.transaction(() async {
        await payLater.unlinkExpense('e2');
        await ReconcileTabUseCase(repository: payLater)('t1');
      });
      expect((await balance('t1')).credit, 3);

      await useCase.delete('p1');

      expect(await paidOn('t1'), {'e1': 2000});
      expect((await balance('t1')).owed, 0);
      expect((await balance('t1')).credit, 1);
    });

    test('delete of a missing id is notFound and writes nothing', () async {
      await addPurchase('e1', 5);
      await record('p1', 2);

      final result = await useCase.delete('nope');

      expect(failureOf(result).type, PayLaterErrorType.notFound);
      expect(await count('pay_later_payments'), 1);
      expect((await balance('t1')).owed, 3);
    });

    test('a failed reconcile rolls the delete back', () async {
      await addPurchase('e1', 2, hour: 9);
      await addPurchase('e2', 3, hour: 13);
      await record('p1', 2);
      await record('p2', 3);
      // e2 leaves the tab: p2's 3 becomes credit, which the reconcile after
      // deleting p1 would move onto e1.
      await payLater.transaction(() async {
        await payLater.unlinkExpense('e2');
        await ReconcileTabUseCase(repository: payLater)('t1');
      });
      TabPayment? paymentWhenWriteFailed;
      payLater
        ..failApplyDiff = true
        ..onFail = () async {
          paymentWhenWriteFailed = await payLater.getPayment('p1');
        };

      final result = await useCase.delete('p1');

      // The delete had run inside the transaction...
      expect(paymentWhenWriteFailed, isNull);
      // ...and rolled back with the failed reconcile write.
      expect(failureOf(result).type, PayLaterErrorType.databaseFailure);
      expect(await payLater.getPayment('p1'), isNotNull);
      expect(await paidOn('t1'), {'e1': 2000});
      expect((await balance('t1')).owed, 0);
      expect((await balance('t1')).credit, 3);
    });
  });

  group('owedAfter', () {
    test('is owed minus the amount, in units, never below zero', () async {
      await addPurchase('e1', 0.1, hour: 9);
      await addPurchase('e2', 0.2, hour: 13);

      expect(
        await useCase.owedAfter(tabId: 't1', amount: 0.1),
        isA<PayLaterSuccess<double>>().having((s) => s.data, 'data', 0.2),
      );
      expect(
        await useCase.owedAfter(tabId: 't1', amount: 0.3),
        isA<PayLaterSuccess<double>>().having((s) => s.data, 'data', 0),
      );
      expect(
        await useCase.owedAfter(tabId: 't1', amount: 9),
        isA<PayLaterSuccess<double>>().having((s) => s.data, 'data', 0),
      );
      expect(
        await useCase.owedAfter(tabId: 't1', amount: 0),
        isA<PayLaterSuccess<double>>().having((s) => s.data, 'data', 0.3),
      );
      expect(await count('pay_later_payments'), 0);
    });

    test('a missing tab is notFound', () async {
      final result = await useCase.owedAfter(tabId: 'nope', amount: 1);

      expect(failureOf(result).type, PayLaterErrorType.notFound);
    });
  });
}
