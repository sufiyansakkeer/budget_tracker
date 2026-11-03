import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_overview.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_overview_usecase.dart';

import '../../../helpers/pay_later_fakes.dart';
import '../../../helpers/pay_later_fixtures.dart';

/// A purchase of [amount] on [date] (noon), created on 2 Nov.
ExpenseEntity purchase(String id, double amount, DateTime date) =>
    payLaterExpense(id, amount: amount).copyWith(
      date: date,
      time: DateTime(date.year, date.month, date.day, 12),
      createdAt: DateTime(2026, 11, 2, 9),
    );

/// A payment of [amount] that changed hands on [paidDate], recorded on 2 Nov.
TabPayment payment(String id, String tabId, double amount, DateTime paidDate) =>
    TabPayment(
      id: id,
      tabId: tabId,
      amount: amount,
      paidDate: paidDate,
      createdAt: DateTime(2026, 11, 2, 9),
      updatedAt: DateTime(2026, 11, 2, 9),
    );

void main() {
  /// 2 Nov 2026, 10:00 (the day after US DST ends).
  final now = DateTime(2026, 11, 2, 10);

  late List<PayLaterTab> tabs;
  late FakeGetTabLedgerUseCase ledger;
  late GetPayLaterOverviewUseCase overview;

  setUp(() {
    tabs = [];
    ledger = FakeGetTabLedgerUseCase(tabs: tabs, clock: () => now);
    overview = GetPayLaterOverviewUseCase(
      getTabs: FakeGetTabsUseCase(tabs),
      getLedger: ledger,
      clock: () => now,
    );
  });

  Future<PayLaterOverview> load() async {
    final result = await overview();
    expect(result, isA<PayLaterSuccess<PayLaterOverview>>());
    return (result as PayLaterSuccess<PayLaterOverview>).data;
  }

  test('totals never mix currencies', () async {
    tabs
      ..add(payLaterTab('omr', name: 'Cafeteria'))
      ..add(payLaterTab('inr', name: 'Kirana', currency: 'INR'))
      ..add(payLaterTab('omr2', name: 'Bakery'));
    ledger.purchases['omr'] = [purchase('e1', 5.250, DateTime(2026, 11, 1))];
    ledger.purchases['omr2'] = [purchase('e2', 0.750, DateTime(2026, 11, 1))];
    ledger.purchases['inr'] = [purchase('e3', 300, DateTime(2026, 11, 1))];

    final data = await load();

    expect(data.totals.map((t) => t.currency).toSet(), {'OMR', 'INR'});
    final omr = data.totals.singleWhere((t) => t.currency == 'OMR');
    final inr = data.totals.singleWhere((t) => t.currency == 'INR');
    expect(omr.owed, 6.0);
    expect(inr.owed, 300.0);
  });

  test('archived tab with balance counts in totals', () async {
    tabs
      ..add(payLaterTab('active', name: 'Cafeteria'))
      ..add(payLaterTab('idle', name: 'Aardvark shop'))
      ..add(payLaterTab('owing', name: 'Old shop').copyWith(isArchived: true))
      ..add(payLaterTab('done', name: 'Closed').copyWith(isArchived: true));
    ledger.purchases['active'] = [purchase('e1', 5, DateTime(2026, 11, 1))];
    ledger.purchases['owing'] = [purchase('e2', 3, DateTime(2026, 10, 20))];

    final data = await load();

    expect(data.totals.single.owed, 8.0);
    // Owing tabs first (archived or not), then other active, archived last.
    expect(data.tabs.map((l) => l.tab.id).toList(), [
      'active',
      'owing',
      'idle',
      'done',
    ]);
    expect(data.activeTabCount, 2);
  });

  test('an archived tab in credit stays among the active ones', () async {
    tabs
      ..add(payLaterTab('idle', name: 'Aardvark shop'))
      ..add(payLaterTab('credit', name: 'Zed').copyWith(isArchived: true));
    ledger.payments['credit'] = [
      payment('p1', 'credit', 2, DateTime(2026, 10, 20)),
    ];

    final data = await load();

    expect(data.tabs.map((l) => l.tab.id).toList(), ['credit', 'idle']);
  });

  test('this month figures use purchase date and paid date', () async {
    tabs.add(payLaterTab('t1'));
    ledger.purchases['t1'] = [
      // Bought in October, entered in November: not this month.
      purchase('oct', 4, DateTime(2026, 10, 31)),
      purchase('nov1', 2.5, DateTime(2026, 11, 1)),
      purchase('nov2', 1, DateTime(2026, 11, 2)),
    ];
    ledger.payments['t1'] = [
      // Handed over in October, recorded in November: not this month.
      payment('p-oct', 't1', 1.5, DateTime(2026, 10, 30)),
      payment('p-nov', 't1', 2, DateTime(2026, 11, 1)),
    ];

    final totals = (await load()).totals.single;

    expect(totals.addedThisMonth, 3.5);
    expect(totals.paidThisMonth, 2.0);
    expect(totals.owed, 4.0);
  });

  test('overdue and upcoming come from each ledger', () async {
    final anchor = DateTime(2026, 10, 1);
    tabs
      ..add(payLaterTab('weekly', rhythm: EveryDays(days: 7, anchor: anchor)))
      ..add(
        payLaterTab(
          'fortnight',
          name: 'Bakery',
          rhythm: EveryDays(days: 14, anchor: anchor),
        ),
      )
      ..add(
        payLaterTab(
          'settled',
          name: 'Shop',
          rhythm: EveryDays(days: 7, anchor: anchor),
        ),
      );
    // Period 1–7 Oct settles on 8 Oct: overdue.
    ledger.purchases['weekly'] = [
      purchase('old', 3, DateTime(2026, 10, 2)),
      purchase('new', 1, DateTime(2026, 11, 1)),
    ];
    ledger.purchases['fortnight'] = [purchase('b', 2, DateTime(2026, 11, 1))];

    final data = await load();

    expect(data.totals.single.overdue, 3.0);
    // Weekly: 29 Oct–4 Nov settles 5 Nov. Fortnight: 29 Oct–11 Nov settles
    // 12 Nov. The settled tab owes nothing, so it isn't upcoming.
    expect(data.upcoming.map((u) => (u.$1.id, u.$2)).toList(), [
      ('weekly', DateTime(2026, 11, 5)),
      ('fortnight', DateTime(2026, 11, 12)),
    ]);
    // Overdue tabs lead the owing group.
    expect(data.tabs.first.tab.id, 'weekly');
  });

  test('recent purchases and payments are newest first', () async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(payLaterTab('t2', name: 'Bakery'));
    ledger.purchases['t1'] = [
      purchase('a', 1, DateTime(2026, 10, 1)),
      purchase('c', 1, DateTime(2026, 11, 2)),
    ];
    ledger.purchases['t2'] = [purchase('b', 1, DateTime(2026, 10, 15))];
    ledger.payments['t1'] = [payment('p1', 't1', 1, DateTime(2026, 10, 2))];
    ledger.payments['t2'] = [payment('p2', 't2', 1, DateTime(2026, 10, 20))];

    final data = await load();

    expect(data.recentPurchases.map((l) => l.expense.id).toList(), [
      'c',
      'b',
      'a',
    ]);
    expect(data.recentPayments.map((l) => l.payment.id).toList(), ['p2', 'p1']);
    expect(data.tabForPurchase('b')?.id, 't2');
    expect(data.tabForPayment(data.recentPayments.first)?.id, 't2');
  });

  test('a currency with only settled archived tabs has no totals', () async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(
        payLaterTab(
          'old',
          name: 'Old',
          currency: 'INR',
        ).copyWith(isArchived: true),
      );

    final data = await load();

    expect(data.totals.map((t) => t.currency).toList(), ['OMR']);
    expect(data.totals.single.owed, 0.0);
  });

  test('no tabs gives an empty overview', () async {
    final data = await load();

    expect(data.tabs, isEmpty);
    expect(data.totals, isEmpty);
    expect(data.isEmpty, isTrue);
  });

  test('a ledger that fails to load fails the overview', () async {
    tabs.add(payLaterTab('t1'));
    ledger.failing.add('t1');

    final result = await overview();

    expect(result, isA<PayLaterError<PayLaterOverview>>());
    expect(
      (result as PayLaterError<PayLaterOverview>).failure.type,
      PayLaterErrorType.databaseFailure,
    );
  });

  test('a tab list that fails to load fails the overview', () async {
    final failing = FakeGetTabsUseCase()..fail = true;
    final result = await GetPayLaterOverviewUseCase(
      getTabs: failing,
      getLedger: ledger,
      clock: () => now,
    )();

    expect(result, isA<PayLaterError<PayLaterOverview>>());
  });
}
