import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_overview.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_ledger.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_analytics_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_overview_usecase.dart';

import '../../../helpers/pay_later_fakes.dart';
import '../../../helpers/pay_later_fixtures.dart';

ExpenseEntity purchase(
  String id,
  double amount,
  DateTime date, {
  String category = 'cat',
}) => payLaterExpense(id, amount: amount).copyWith(
  date: date,
  time: DateTime(date.year, date.month, date.day, 12),
  categoryId: category,
  createdAt: DateTime(2026, 11, 2, 9),
);

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
  late DateTime now;
  late List<PayLaterTab> tabs;
  late FakeGetTabLedgerUseCase ledger;
  late GetPayLaterAnalyticsUseCase analytics;

  setUp(() {
    now = DateTime(2026, 11, 2, 10);
    tabs = [];
    ledger = FakeGetTabLedgerUseCase(tabs: tabs, clock: () => now);
    analytics = GetPayLaterAnalyticsUseCase(
      getTabs: FakeGetTabsUseCase(tabs),
      getLedger: ledger,
      clock: () => now,
    );
  });

  Future<PayLaterAnalytics> load(String currency, {String? tabId}) async {
    final result = await analytics(currency: currency, tabId: tabId);
    expect(result, isA<PayLaterSuccess<PayLaterAnalytics>>());
    return (result as PayLaterSuccess<PayLaterAnalytics>).data;
  }

  Future<TabLedger> ledgerOf(String tabId) async =>
      ((await ledger(tabId)) as PayLaterSuccess<TabLedger>).data;

  test('months are the last six calendar months, oldest first', () async {
    now = DateTime(2027, 2, 3, 8);
    tabs.add(payLaterTab('t1'));

    final data = await load('OMR');

    expect(data.currency, 'OMR');
    expect(data.months.map((m) => m.month).toList(), [
      DateTime(2026, 9),
      DateTime(2026, 10),
      DateTime(2026, 11),
      DateTime(2026, 12),
      DateTime(2027, 1),
      DateTime(2027, 2),
    ]);
  });

  test('added and paid go by purchase date and paid date', () async {
    tabs.add(payLaterTab('t1'));
    ledger.purchases['t1'] = [
      purchase('sep', 3, DateTime(2026, 9, 10)),
      purchase('oct-last', 2.5, DateTime(2026, 10, 31)),
      purchase('nov-first', 1, DateTime(2026, 11, 1)),
    ];
    ledger.payments['t1'] = [
      payment('p-sep', 't1', 2, DateTime(2026, 9, 30)),
      payment('p-oct', 't1', 3.5, DateTime(2026, 10, 31)),
    ];

    final months = (await load('OMR')).months;

    expect([for (final m in months) m.added], [0, 0, 0, 3, 2.5, 1]);
    expect([for (final m in months) m.paid], [0, 0, 0, 2, 3.5, 0]);
  });

  test('owed at month end matches ledger', () async {
    tabs.add(payLaterTab('t1'));
    ledger.purchases['t1'] = [
      purchase('sep', 3, DateTime(2026, 9, 10)),
      purchase('oct', 2.5, DateTime(2026, 10, 25)),
      purchase('nov', 1, DateTime(2026, 11, 1)),
    ];
    ledger.payments['t1'] = [
      payment('p-sep', 't1', 2, DateTime(2026, 9, 30)),
      payment('p-oct', 't1', 3.5, DateTime(2026, 10, 31)),
    ];

    final months = (await load('OMR')).months;
    final tab = await ledgerOf('t1');

    expect([for (final m in months) m.owedAtEnd], [0, 0, 0, 1, 0, 1]);
    // The month's last payment leaves what the ledger says it left.
    expect(months[3].owedAtEnd, tab.payments[0].balanceAfter);
    expect(months[4].owedAtEnd, tab.payments[1].balanceAfter);
    // This month ends where the tab stands today.
    expect(months.last.owedAtEnd, tab.owed - tab.credit);
  });

  test('owed at month end is exact in fils and never below zero', () async {
    tabs.add(payLaterTab('t1'));
    ledger.purchases['t1'] = [
      purchase('a', 0.350, DateTime(2026, 10, 1)),
      purchase('b', 0.350, DateTime(2026, 10, 2)),
      purchase('c', 0.350, DateTime(2026, 10, 3)),
    ];
    ledger.payments['t1'] = [
      payment('p1', 't1', 0.700, DateTime(2026, 10, 4)),
      // Overpaid in November (as after a purchase was later deleted).
      payment('p2', 't1', 0.500, DateTime(2026, 11, 1)),
    ];

    final months = (await load('OMR')).months;

    expect(months[4].owedAtEnd, 0.350);
    expect(months[4].added, 1.050);
    // In credit 0.150: nothing is owed, and credit isn't shown as debt.
    expect(months[5].owedAtEnd, 0);
  });

  test('credit on one tab never offsets what another tab owes', () async {
    tabs
      ..add(payLaterTab('a', name: 'Cafeteria'))
      ..add(payLaterTab('b', name: 'Bakery'));
    ledger.purchases['a'] = [purchase('a1', 10, DateTime(2026, 10, 1))];
    // Tab b is 4 in credit (paid 5 against a 1 purchase).
    ledger.purchases['b'] = [purchase('b1', 1, DateTime(2026, 10, 1))];
    ledger.payments['b'] = [payment('pb', 'b', 5, DateTime(2026, 10, 2))];

    final months = (await load('OMR')).months;
    final headline = await GetPayLaterOverviewUseCase(
      getTabs: FakeGetTabsUseCase(tabs),
      getLedger: ledger,
      clock: () => now,
    )();
    final owed =
        (headline as PayLaterSuccess<PayLaterOverview>).data.totals.single.owed;

    expect(owed, 10);
    expect(months.last.owedAtEnd, owed);
    expect(months[4].owedAtEnd, 10);
  });

  test('only tabs in the asked currency count', () async {
    tabs
      ..add(payLaterTab('omr'))
      ..add(payLaterTab('inr', name: 'Kirana', currency: 'INR'));
    ledger.purchases['omr'] = [purchase('a', 1, DateTime(2026, 11, 1))];
    ledger.purchases['inr'] = [purchase('b', 300, DateTime(2026, 11, 1))];

    final data = await load('INR');

    expect(data.months.last.added, 300);
    expect(data.byTab, {'inr': 300.0});
  });

  test('breakdowns sum every purchase by category and by tab', () async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(payLaterTab('t2', name: 'Bakery').copyWith(isArchived: true));
    ledger.purchases['t1'] = [
      purchase('a', 1.250, DateTime(2026, 1, 5), category: 'food'),
      purchase('b', 2, DateTime(2026, 11, 1), category: 'snacks'),
    ];
    ledger.purchases['t2'] = [
      purchase('c', 0.750, DateTime(2026, 11, 1), category: 'food'),
    ];

    final data = await load('OMR');

    expect(data.byExpenseCategory, {'food': 2.0, 'snacks': 2.0});
    expect(data.byTab, {'t1': 3.25, 't2': 0.75});
    expect(data.periodComparison, isEmpty);
  });

  test('one tab: its own figures and its periods', () async {
    tabs
      ..add(
        payLaterTab(
          't1',
          rhythm: EveryDays(days: 14, anchor: DateTime(2026, 10, 1)),
        ),
      )
      ..add(payLaterTab('t2', name: 'Bakery'));
    ledger.purchases['t1'] = [
      purchase('a', 1, DateTime(2026, 10, 2)),
      purchase('b', 2, DateTime(2026, 10, 20)),
    ];
    ledger.purchases['t2'] = [purchase('c', 9, DateTime(2026, 10, 2))];

    final data = await load('OMR', tabId: 't1');

    expect(data.byTab, {'t1': 3.0});
    expect(data.months[4].added, 3);
    expect(data.periodComparison, (await ledgerOf('t1')).periods);
    expect(data.periodComparison, hasLength(2));
  });

  test('a tab in another currency is refused', () async {
    tabs.add(payLaterTab('t1'));

    final result = await analytics(currency: 'INR', tabId: 't1');

    expect(result, isA<PayLaterError<PayLaterAnalytics>>());
    expect(
      (result as PayLaterError<PayLaterAnalytics>).failure.type,
      PayLaterErrorType.invalidInput,
    );
  });

  test('a ledger that fails to load fails the analytics', () async {
    tabs.add(payLaterTab('t1'));
    ledger.failing.add('t1');

    final result = await analytics(currency: 'OMR');

    expect(result, isA<PayLaterError<PayLaterAnalytics>>());
    expect(
      (result as PayLaterError<PayLaterAnalytics>).failure.type,
      PayLaterErrorType.databaseFailure,
    );
  });
}
