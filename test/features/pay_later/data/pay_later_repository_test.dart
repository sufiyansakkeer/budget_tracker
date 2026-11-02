import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/payment_allocation.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/repository/pay_later_repository.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_allocator.dart';

import '../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase db;
  late PayLaterRepository repo;

  final stamp = DateTime(2026, 11, 1, 9);

  PayLaterTab tab(
    String id, {
    SettleRhythm rhythm = const OnDemand(),
    String name = 'Cafeteria',
  }) => PayLaterTab(
    id: id,
    name: name,
    category: PayLaterTabCategory.foodDining,
    currency: 'OMR',
    note: 'note',
    contact: '123',
    defaultCategoryId: 'cat',
    rhythm: rhythm,
    reminderEnabled: true,
    reminderOffsetDays: 2,
    isArchived: true,
    createdAt: stamp,
    updatedAt: stamp,
  );

  ExpenseEntity expense(
    String id, {
    String budgetId = 'b1',
    DateTime? date,
    DateTime? time,
    DateTime? createdAt,
  }) => ExpenseEntity(
    id: id,
    budgetId: budgetId,
    amount: 5,
    categoryId: 'cat',
    date: date ?? DateTime(2026, 11, 1),
    time: time ?? DateTime(2026, 11, 1, 12),
    createdAt: createdAt ?? stamp,
    updatedAt: stamp,
  );

  Future<void> addBudget(String id) => db
      .into(db.budgets)
      .insert(
        BudgetsCompanion.insert(
          id: id,
          name: id,
          monthlyAmount: 100,
          remainingAmount: 100,
          currency: 'OMR',
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
      );

  Future<void> addExpense(ExpenseEntity e) =>
      ExpenseLocalDataSourceImpl(database: db).createExpense(e);

  TabPayment payment(String id, String tabId) => TabPayment(
    id: id,
    tabId: tabId,
    amount: 10,
    paidDate: DateTime(2026, 11, 2),
    note: 'cash',
    createdAt: stamp,
    updatedAt: stamp,
  );

  PaymentAllocation alloc(
    String id,
    String paymentId,
    String expenseId,
    double amount,
  ) => PaymentAllocation(
    id: id,
    paymentId: paymentId,
    expenseId: expenseId,
    amount: amount,
    isManual: false,
    createdAt: stamp,
  );

  setUp(() async {
    db = await createInMemoryDatabase();
    repo = PayLaterRepositoryImpl(
      localDataSource: PayLaterLocalDataSourceImpl(database: db),
    );
    await addBudget('b1');
    await addBudget('b2');
    await db
        .into(db.categories)
        .insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: 'cat',
            name: 'Cat',
            icon: 'i',
            colorHex: '#000000',
          ),
        );
  });

  tearDown(() => db.close());

  test('tab round-trips every column for each rhythm', () async {
    final rhythms = <SettleRhythm>[
      const OnDemand(),
      EveryDays(days: 14, anchor: DateTime(2026, 10, 1)),
      const MonthlyDay(day: 25),
      ManualDate(
        nextSettleDate: DateTime(2026, 12, 5),
        anchor: DateTime(2026, 11, 5),
      ),
      const ManualDate(),
    ];
    for (var i = 0; i < rhythms.length; i++) {
      final t = tab('t$i', rhythm: rhythms[i]);
      await repo.createTab(t);
      expect(await repo.getTab('t$i'), t);
    }
    expect((await repo.getTabs()).length, rhythms.length);

    final changed = tab('t0', rhythm: const MonthlyDay(day: 3), name: 'Renamed')
        .copyWith(
          clearNote: true,
          clearContact: true,
          clearDefaultCategoryId: true,
        );
    await repo.updateTab(changed);
    expect(await repo.getTab('t0'), changed);
    expect(await repo.getTab('missing'), isNull);
  });

  test('purchasesOf returns linked expenses in FIFO order', () async {
    await repo.createTab(tab('t'));
    await addExpense(
      expense('c', date: DateTime(2026, 11, 2), time: DateTime(2026, 11, 2, 8)),
    );
    await addExpense(
      expense(
        'b',
        date: DateTime(2026, 11, 1),
        time: DateTime(2026, 11, 1, 18),
      ),
    );
    await addExpense(
      expense('a', date: DateTime(2026, 11, 1), time: DateTime(2026, 11, 1, 9)),
    );
    await addExpense(
      expense(
        'b2',
        date: DateTime(2026, 11, 1),
        time: DateTime(2026, 11, 1, 18),
        createdAt: stamp.add(const Duration(minutes: 1)),
      ),
    );
    await addExpense(expense('other'));
    for (final id in ['c', 'b', 'a', 'b2']) {
      await repo.linkExpense(expenseId: id, tabId: 't');
    }

    final purchases = await repo.purchasesOf('t');
    expect(purchases.map((e) => e.id), ['a', 'b', 'b2', 'c']);
    expect(await repo.tabIdForExpense('a'), 't');
    expect(await repo.tabIdForExpense('other'), isNull);

    await repo.unlinkExpense('a');
    expect(await repo.tabIdForExpense('a'), isNull);
    expect((await repo.purchasesOf('t')).length, 3);
  });

  test('applyDiff inserts, updates and deletes', () async {
    await repo.createTab(tab('t'));
    await addExpense(expense('e1'));
    await addExpense(expense('e2'));
    await repo.linkExpense(expenseId: 'e1', tabId: 't');
    await repo.linkExpense(expenseId: 'e2', tabId: 't');
    await repo.createPayment(payment('p', 't'));
    await repo.applyDiff(AllocationDiff(inserts: [alloc('a1', 'p', 'e1', 5)]));
    expect((await repo.allocationsOf('t')).single.id, 'a1');

    // Delete + insert for the same (payment, expense) pair in one diff only
    // works when deletes run first.
    await repo.applyDiff(
      AllocationDiff(
        inserts: [alloc('a2', 'p', 'e1', 3), alloc('a3', 'p', 'e2', 2)],
        deletes: {'a1'},
      ),
    );
    var all = await repo.allocationsOf('t');
    expect(all.map((a) => a.id).toSet(), {'a2', 'a3'});

    await repo.applyDiff(
      const AllocationDiff(updates: {'a2': 4.5}, deletes: {'a3'}),
    );
    all = await repo.allocationsOf('t');
    expect(all.single.id, 'a2');
    expect(all.single.amount, 4.5);

    expect(await repo.getPayment('p'), payment('p', 't'));
    final edited = payment('p', 't').copyWith(amount: 12, clearNote: true);
    await repo.updatePayment(edited);
    expect(await repo.getPayment('p'), edited);
    expect((await repo.paymentsOf('t')).single, edited);

    await repo.deletePayment('p');
    expect(await repo.getPayment('p'), isNull);
    expect(await repo.allocationsOf('t'), isEmpty);
  });

  test('transaction rolls back every write when the action throws', () async {
    await expectLater(
      repo.transaction(() async {
        await repo.createTab(tab('t'));
        await repo.createPayment(payment('p', 't'));
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(await repo.getTab('t'), isNull);
    expect(await repo.getPayment('p'), isNull);
  });

  test(
    'nested transaction from another datasource joins the outer one',
    () async {
      await expectLater(
        repo.transaction(() async {
          await ExpenseLocalDataSourceImpl(
            database: db,
          ).transaction(() => addExpense(expense('inner')));
          throw StateError('boom');
        }),
        throwsStateError,
      );
      final rows = await (db.select(
        db.expenses,
      )..where((e) => e.id.equals('inner'))).get();
      expect(rows, isEmpty);
    },
  );

  test('deleting a tab with activity throws', () async {
    await repo.createTab(tab('t'));
    await repo.createPayment(payment('p', 't'));
    await expectLater(repo.deleteTab('t'), throwsA(anything));
    expect(await repo.getTab('t'), isNotNull);

    await repo.createTab(tab('empty'));
    await repo.deleteTab('empty');
    expect(await repo.getTab('empty'), isNull);
  });

  test('tabHasActivity', () async {
    await repo.createTab(tab('link'));
    await repo.createTab(tab('pay'));
    await repo.createTab(tab('none'));
    await addExpense(expense('e'));
    await repo.linkExpense(expenseId: 'e', tabId: 'link');
    await repo.createPayment(payment('p', 'pay'));

    expect(await repo.tabHasActivity('link'), isTrue);
    expect(await repo.tabHasActivity('pay'), isTrue);
    expect(await repo.tabHasActivity('none'), isFalse);
    expect((await repo.tabIdsWithActivity()).toSet(), {'link', 'pay'});
  });

  test('tabIdsWithPurchasesInBudget', () async {
    await repo.createTab(tab('t1'));
    await repo.createTab(tab('t2'));
    await addExpense(expense('e1', budgetId: 'b1'));
    await addExpense(expense('e2', budgetId: 'b1'));
    await addExpense(expense('e3', budgetId: 'b2'));
    await repo.linkExpense(expenseId: 'e1', tabId: 't1');
    await repo.linkExpense(expenseId: 'e2', tabId: 't1');
    await repo.linkExpense(expenseId: 'e3', tabId: 't2');

    expect(await repo.purchasesInBudget('b1'), 2);
    expect(await repo.purchasesInBudget('b2'), 1);
    expect(await repo.tabIdsWithPurchasesInBudget('b1'), ['t1']);
    expect(await repo.tabIdsWithPurchasesInBudget('b2'), ['t2']);
  });
}
