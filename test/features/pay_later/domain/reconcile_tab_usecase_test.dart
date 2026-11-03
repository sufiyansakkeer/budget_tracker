import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_ledger.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/repository/pay_later_repository.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tab_ledger_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';

import 'package:monivo/features/pay_later/domain/services/pay_later_allocator.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/payment_allocation.dart';

import '../../../helpers/in_memory_database.dart';
import '../../../helpers/pay_later_fixtures.dart';

/// The real repository, noting how deep in transactions each read and
/// write runs.
class _TxRepository extends PayLaterRepositoryImpl {
  _TxRepository(AppDatabase db)
    : super(localDataSource: PayLaterLocalDataSourceImpl(database: db));

  int depth = 0;
  int transactions = 0;
  final List<(String, int)> events = [];

  /// applyDiff fails for allocations of this tab's payments.
  String? failDiffFor;

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      super.transaction(() async {
        transactions++;
        depth++;
        try {
          return await action();
        } finally {
          depth--;
        }
      });

  @override
  Future<PayLaterTab?> getTab(String id) {
    events.add(('getTab', depth));
    return super.getTab(id);
  }

  @override
  Future<List<ExpenseEntity>> purchasesOf(String tabId) {
    events.add(('purchasesOf', depth));
    return super.purchasesOf(tabId);
  }

  @override
  Future<List<TabPayment>> paymentsOf(String tabId) {
    events.add(('paymentsOf', depth));
    return super.paymentsOf(tabId);
  }

  @override
  Future<List<PaymentAllocation>> allocationsOf(String tabId) {
    events.add(('allocationsOf', depth));
    return super.allocationsOf(tabId);
  }

  @override
  Future<void> applyDiff(AllocationDiff diff) async {
    events.add(('applyDiff', depth));
    final fail = failDiffFor;
    if (fail != null &&
        diff.inserts.any((a) => a.paymentId.startsWith('$fail-'))) {
      throw StateError('allocation write failed');
    }
    return super.applyDiff(diff);
  }
}

void main() {
  late AppDatabase db;
  late PayLaterRepository repo;
  late ReconcileTabUseCase reconcile;

  setUp(() async {
    db = await createInMemoryDatabase();
    repo = PayLaterRepositoryImpl(
      localDataSource: PayLaterLocalDataSourceImpl(database: db),
    );
    reconcile = ReconcileTabUseCase(repository: repo);
    await seedPayLaterBudget(db);
    await repo.createTab(payLaterTab('t1'));
    await repo.createTab(payLaterTab('t2'));
    await repo.createTab(payLaterTab('idle'));
    for (final (tab, id, amount) in [
      ('t1', 'e1', 5.0),
      ('t1', 'e2', 8.0),
      ('t2', 'e3', 3.0),
    ]) {
      await addPayLaterExpense(db, payLaterExpense(id, amount: amount));
      await repo.linkExpense(expenseId: id, tabId: tab);
    }
    await repo.createPayment(
      TabPayment(
        id: 'p1',
        tabId: 't1',
        amount: 10,
        paidDate: DateTime(2026, 11, 2),
        createdAt: payLaterStamp,
        updatedAt: payLaterStamp,
      ),
    );
  });

  tearDown(() => db.close());

  Future<List<(String, String, double)>> snapshot() async => [
    for (final t in ['t1', 't2'])
      for (final a in await repo.allocationsOf(t))
        (a.paymentId, a.expenseId, a.amount),
  ]..sort((a, b) => '${a.$1}${a.$2}'.compareTo('${b.$1}${b.$2}'));

  test('call allocates a payment across the tab purchases (FIFO)', () async {
    await repo.transaction(() => reconcile('t1'));
    expect(await snapshot(), [('p1', 'e1', 5.0), ('p1', 'e2', 5.0)]);
  });

  test(
    'call keeps allocations whose purchase and payment still exist',
    () async {
      await repo.transaction(() => reconcile('t1'));
      final before = await repo.allocationsOf('t1');
      await repo.transaction(() => reconcile('t1'));
      final after = await repo.allocationsOf('t1');
      expect({for (final a in before) a.id}, {for (final a in after) a.id});
    },
  );

  test('call removes allocations of an unlinked purchase', () async {
    await repo.transaction(() => reconcile('t1'));
    await repo.unlinkExpense('e1');
    await repo.transaction(() => reconcile('t1'));
    expect(await snapshot(), [('p1', 'e2', 8.0)]);
  });

  test('call on a missing tab does nothing', () async {
    await reconcile('missing');
    expect(await snapshot(), isEmpty);
  });

  test('reconcile all is idempotent and covers every active tab', () async {
    await reconcile.all();
    final first = await snapshot();
    expect(first, isNotEmpty);
    await reconcile.all();
    expect(await snapshot(), first);
    expect(await repo.allocationsOf('idle'), isEmpty);
  });

  group('GetTabLedgerUseCase', () {
    late GetTabLedgerUseCase ledger;

    setUp(() {
      ledger = GetTabLedgerUseCase(
        repository: repo,
        clock: () => DateTime(2026, 11, 2),
      );
    });

    test('builds the ledger without reconciling or writing', () async {
      final r = await ledger('t1');
      expect(r, isA<PayLaterSuccess<TabLedger>>());
      final l = (r as PayLaterSuccess<TabLedger>).data;
      // Stored allocations are empty, so nothing is applied yet.
      expect(l.owed, 13);
      expect(l.credit, 10);
      expect(await repo.allocationsOf('t1'), isEmpty);
    });

    test('reflects stored allocations after a reconcile', () async {
      await repo.transaction(() => reconcile('t1'));
      final l = ((await ledger('t1')) as PayLaterSuccess<TabLedger>).data;
      expect(l.owed, 3);
      expect(l.credit, 0);
    });

    test('missing tab is notFound', () async {
      final r = await ledger('nope');
      expect(
        (r as PayLaterError<TabLedger>).failure.type,
        PayLaterErrorType.notFound,
      );
    });
  });

  group('transactions (M2, M3)', () {
    late _TxRepository tx;

    setUp(() async {
      tx = _TxRepository(db);
      // A payment on t2 too, so both tabs have something to write.
      await tx.createPayment(
        TabPayment(
          id: 't2-p',
          tabId: 't2',
          amount: 1,
          paidDate: DateTime(2026, 11, 2),
          createdAt: payLaterStamp,
          updatedAt: payLaterStamp,
        ),
      );
      tx.events.clear();
    });

    test('a ledger reads its rows in one transaction (one snapshot)', () async {
      final ledger = GetTabLedgerUseCase(
        repository: tx,
        clock: () => DateTime(2026, 11, 2),
      );

      expect(await ledger('t1'), isA<PayLaterSuccess<TabLedger>>());

      expect(tx.transactions, 1);
      expect(tx.events.map((e) => e.$1), [
        'getTab',
        'purchasesOf',
        'paymentsOf',
        'allocationsOf',
      ]);
      expect(tx.events.every((e) => e.$2 == 1), isTrue, reason: '${tx.events}');
    });

    test('reconcile all commits one tab at a time', () async {
      await ReconcileTabUseCase(repository: tx).all();

      // t1 and t2 have activity; idle has none.
      expect(tx.transactions, 2);
      final writes = tx.events.where((e) => e.$1 == 'applyDiff').toList();
      expect(writes, hasLength(2));
      expect(writes.every((e) => e.$2 == 1), isTrue, reason: '$writes');
    });

    test('a failing tab keeps the tabs already reconciled', () async {
      tx.failDiffFor = 't2';

      await expectLater(
        ReconcileTabUseCase(repository: tx).all(),
        throwsA(isA<StateError>()),
      );

      expect(await tx.allocationsOf('t1'), isNotEmpty);
      expect(await tx.allocationsOf('t2'), isEmpty);
    });

    test('inside an outer transaction (restore) it nests and rolls back '
        'with it', () async {
      tx.failDiffFor = 't2';

      await expectLater(
        tx.transaction(() => ReconcileTabUseCase(repository: tx).all()),
        throwsA(isA<StateError>()),
      );

      // The outer transaction rolled every tab back.
      expect(await tx.allocationsOf('t1'), isEmpty);
    });
  });
}
