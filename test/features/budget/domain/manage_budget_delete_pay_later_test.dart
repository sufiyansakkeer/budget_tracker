import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_allocator.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';

import '../../../helpers/in_memory_database.dart';
import '../../../helpers/pay_later_fixtures.dart';

/// The real Pay Later repository, counting allocation writes and failing
/// them on demand.
class _CountingPayLaterRepository extends PayLaterRepositoryImpl {
  _CountingPayLaterRepository(AppDatabase db)
    : super(localDataSource: PayLaterLocalDataSourceImpl(database: db));

  int diffWrites = 0;
  bool failDiff = false;

  @override
  Future<void> applyDiff(AllocationDiff diff) async {
    if (failDiff) throw StateError('allocation write failed');
    diffWrites++;
    return super.applyDiff(diff);
  }
}

void main() {
  late AppDatabase db;
  late _CountingPayLaterRepository payLater;
  late ReconcileTabUseCase reconcile;
  late ManageBudgetUseCase manageBudget;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await createInMemoryDatabase();
    payLater = _CountingPayLaterRepository(db);
    reconcile = ReconcileTabUseCase(repository: payLater);
    manageBudget = ManageBudgetUseCase(
      repository: BudgetRepositoryImpl(
        localDataSource: BudgetLocalDataSourceImpl(
          database: db,
          sharedPreferences: await SharedPreferences.getInstance(),
        ),
        calculationService: BudgetCalculationService(),
      ),
      reconcileTabs: reconcile,
    );

    // b1 (deleted below) and b2 (kept), both OMR.
    await seedPayLaterBudget(db);
    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'b2',
            name: 'b2',
            monthlyAmount: 100,
            remainingAmount: 100,
            currency: 'OMR',
            startDate: DateTime(2026, 11, 1),
            endDate: DateTime(2026, 11, 30),
          ),
        );
    await payLater.createTab(payLaterTab('t1'));
    await payLater.createTab(payLaterTab('t2', name: 'Shop'));

    // t1: an older purchase of 5 in b1, a newer one of 10 in b2, and a
    // payment of 8 that FIFO spreads 5 + 3. t2: one purchase of 4 in b1,
    // paid in full.
    await addPayLaterExpense(
      db,
      payLaterExpense(
        'old',
        amount: 5,
      ).copyWith(time: DateTime(2026, 11, 1, 9)),
    );
    await addPayLaterExpense(
      db,
      payLaterExpense(
        'new',
        amount: 10,
      ).copyWith(budgetId: 'b2', time: DateTime(2026, 11, 1, 18)),
    );
    await addPayLaterExpense(db, payLaterExpense('shop', amount: 4));
    await payLater.linkExpense(expenseId: 'old', tabId: 't1');
    await payLater.linkExpense(expenseId: 'new', tabId: 't1');
    await payLater.linkExpense(expenseId: 'shop', tabId: 't2');
    for (final (id, tabId, amount) in [('p1', 't1', 8.0), ('p2', 't2', 4.0)]) {
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
    }
    await reconcile.all();
    payLater.diffWrites = 0;
  });

  tearDown(() => db.close());

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('c');

  Future<Map<String, double>> paidOn(String tabId) async => {
    for (final a in await payLater.allocationsOf(tabId)) a.expenseId: a.amount,
  };

  test('the setup spreads each payment FIFO', () async {
    expect(await paidOn('t1'), {'old': 5.0, 'new': 3.0});
    expect(await paidOn('t2'), {'shop': 4.0});
  });

  test('counts the tab purchases inside a budget', () async {
    expect(await reconcile.countPurchasesInBudget('b1'), 2);
    expect(await reconcile.countPurchasesInBudget('b2'), 1);
    expect(await reconcile.countPurchasesInBudget('none'), 0);
  });

  group('currency change (I1)', () {
    test('refused while the budget holds tab purchases', () async {
      final b1 = (await manageBudget.getById('b1'))!;

      await expectLater(
        manageBudget.update(b1.copyWith(currency: 'INR')),
        throwsA(
          isA<BudgetCurrencyLockedException>()
              .having((e) => e.tabPurchases, 'tabPurchases', 2)
              .having((e) => e.currency, 'currency', 'OMR')
              .having(
                (e) => e.message,
                'message',
                '2 purchases in this budget are on Pay later tabs in OMR. '
                    'Move them to another OMR budget or take them off their '
                    'tab first.',
              ),
        ),
      );
      expect((await manageBudget.getById('b1'))!.currency, 'OMR');
    });

    test('other edits of a budget with tab purchases still save', () async {
      final b1 = (await manageBudget.getById('b1'))!;
      await manageBudget.update(b1.copyWith(name: 'Renamed'));
      expect((await manageBudget.getById('b1'))!.name, 'Renamed');
    });

    test('a budget with no tab purchases changes currency as before', () async {
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'b3',
              name: 'b3',
              monthlyAmount: 100,
              remainingAmount: 100,
              currency: 'OMR',
              startDate: DateTime(2026, 11, 1),
              endDate: DateTime(2026, 11, 30),
            ),
          );
      final b3 = (await manageBudget.getById('b3'))!;
      await manageBudget.update(b3.copyWith(currency: 'INR'));
      expect((await manageBudget.getById('b3'))!.currency, 'INR');
    });

    test('one purchase is worded in the singular', () {
      expect(
        const BudgetCurrencyLockedException(
          tabPurchases: 1,
          currency: 'OMR',
        ).message,
        '1 purchase in this budget is on a Pay later tab in OMR. Move it to '
        'another OMR budget or take it off its tab first.',
      );
    });
  });

  test('budget delete reconciles touched tabs idempotently', () async {
    await manageBudget.delete('b1');

    // The b1 purchases went with their budget; t1's money moved onto the
    // purchase still owing, t2's stays as credit.
    expect(await count("SELECT COUNT(*) AS c FROM budgets WHERE id = 'b1'"), 0);
    expect(await payLater.purchasesOf('t1'), hasLength(1));
    expect(await paidOn('t1'), {'new': 8.0});
    expect(await paidOn('t2'), isEmpty);
    expect(await payLater.getPayment('p2'), isNotNull);

    // Reconciling again changes nothing.
    final writes = payLater.diffWrites;
    await reconcile.all();
    expect(payLater.diffWrites, writes);
    expect(await paidOn('t1'), {'new': 8.0});

    // Deleting the other budget takes the last purchase; the payments stay
    // as credit on their tabs.
    await manageBudget.delete('b2');
    expect(await count('SELECT COUNT(*) AS c FROM pay_later_entries'), 0);
    expect(await count('SELECT COUNT(*) AS c FROM pay_later_allocations'), 0);
    expect(await count('SELECT COUNT(*) AS c FROM pay_later_payments'), 2);
  });

  test('budget delete rolls back entirely when reconcile fails', () async {
    payLater.failDiff = true;

    await expectLater(manageBudget.delete('b1'), throwsA(isA<StateError>()));

    expect(await count("SELECT COUNT(*) AS c FROM budgets WHERE id = 'b1'"), 1);
    expect(
      await count("SELECT COUNT(*) AS c FROM expenses WHERE budget_id = 'b1'"),
      2,
    );
    expect(await count('SELECT COUNT(*) AS c FROM pay_later_entries'), 3);
    expect(await paidOn('t1'), {'old': 5.0, 'new': 3.0});
    expect(await paidOn('t2'), {'shop': 4.0});
  });

  test('app start reconcile repairs a corrupted database', () async {
    // As if an older build had written it: 50 paid on a purchase of 5.
    await db.customStatement(
      "UPDATE pay_later_allocations SET amount = 50 WHERE expense_id = 'old'",
    );

    await reconcile.all();
    expect(await paidOn('t1'), {'old': 5.0, 'new': 3.0});

    final writes = payLater.diffWrites;
    await reconcile.all();
    expect(payLater.diffWrites, writes);
  });
}
