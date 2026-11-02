import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/dates/calendar_dates.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/core/router/app_router.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_card.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_overview.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_analytics_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_overview_usecase.dart';
import 'package:monivo/features/pay_later/presentation/bloc/pay_later_overview_bloc.dart';
import 'package:monivo/features/pay_later/presentation/pages/pay_later_overview_screen.dart';
import 'package:monivo/features/pay_later/presentation/widgets/period_group.dart';
import 'package:monivo/features/pay_later/presentation/widgets/tab_tile.dart';

import '../../../helpers/pay_later_fakes.dart';
import '../../../helpers/pay_later_fixtures.dart';

ExpenseEntity purchase(String id, double amount, DateTime date) =>
    payLaterExpense(
      id,
      amount: amount,
    ).copyWith(date: date, time: DateTime(date.year, date.month, date.day, 12));

TabPayment payment(String id, String tabId, double amount, DateTime paidDate) =>
    TabPayment(
      id: id,
      tabId: tabId,
      amount: amount,
      paidDate: paidDate,
      createdAt: paidDate,
      updatedAt: paidDate,
    );

void main() {
  /// 2 Nov 2026, 10:00.
  final now = DateTime(2026, 11, 2, 10);
  final weekly = EveryDays(days: 7, anchor: DateTime(2026, 10, 1));

  late List<PayLaterTab> tabs;
  late FakeGetTabsUseCase getTabs;
  late FakeGetTabLedgerUseCase ledger;

  setUp(() {
    tabs = [];
    getTabs = FakeGetTabsUseCase(tabs);
    ledger = FakeGetTabLedgerUseCase(tabs: tabs, clock: () => now);
  });

  Future<PayLaterOverviewBloc> pump(WidgetTester tester) async {
    final bloc = PayLaterOverviewBloc(
      getOverview: GetPayLaterOverviewUseCase(
        getTabs: getTabs,
        getLedger: ledger,
        clock: () => now,
      ),
      getAnalytics: GetPayLaterAnalyticsUseCase(
        getTabs: getTabs,
        getLedger: ledger,
        clock: () => now,
      ),
    );
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: AppRouter.payLaterPath,
      routes: [
        GoRoute(
          path: AppRouter.payLaterPath,
          builder: (_, _) => BlocProvider.value(
            value: bloc,
            child: const PayLaterOverviewScreen(),
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, _) => const Scaffold(body: Text('New tab form')),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => Scaffold(
                body: Text('Tab detail ${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/app/expenses/add',
          builder: (_, state) => Scaffold(
            body: Text('Add expense ${state.uri.queryParameters['tab']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  Finder tile(String id) => find.byKey(Key('payLaterTab_$id'));

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('empty state offers create a tab', (tester) async {
    await pump(tester);

    expect(find.textContaining('A tab keeps track of'), findsOneWidget);
    expect(find.text('Add to a tab'), findsNothing);
    await tester.tap(find.text('Create a tab'));
    await tester.pumpAndSettle();

    expect(find.text('New tab form'), findsOneWidget);
  });

  testWidgets('tab tile shows owed and overdue badge', (tester) async {
    tabs.add(payLaterTab('t1', rhythm: weekly));
    // 2 Oct settles on 8 Oct (overdue); 1 Nov settles on 5 Nov.
    ledger.purchases['t1'] = [
      purchase('old', 3, DateTime(2026, 10, 2)),
      purchase('new', 1.250, DateTime(2026, 11, 1)),
    ];

    await pump(tester);

    final owed = AppMoney.format(4.25, currency: 'OMR');
    expect(
      find.descendant(of: tile('t1'), matching: find.text(owed)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile('t1'), matching: find.text('Overdue')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tile('t1'),
        matching: find.textContaining('Settle up 5 Nov'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a settled tab has no overdue badge', (tester) async {
    tabs.add(payLaterTab('t1'));
    ledger.purchases['t1'] = [purchase('a', 2, DateTime(2026, 10, 2))];
    ledger.payments['t1'] = [payment('p', 't1', 2, DateTime(2026, 10, 3))];

    await pump(tester);

    expect(
      find.descendant(of: tile('t1'), matching: find.text('Overdue')),
      findsNothing,
    );
    expect(
      find.descendant(of: tile('t1'), matching: find.text('Settled')),
      findsOneWidget,
    );
  });

  testWidgets('totals show each currency on its own', (tester) async {
    tabs
      ..add(payLaterTab('omr'))
      ..add(payLaterTab('inr', name: 'Kirana', currency: 'INR'));
    // Bought last month, so "Added this month" doesn't repeat the figure.
    ledger.purchases['omr'] = [purchase('a', 5.5, DateTime(2026, 10, 1))];
    ledger.purchases['inr'] = [purchase('b', 300, DateTime(2026, 10, 1))];

    await pump(tester);

    final totals = find.byKey(const Key('payLaterTotals'));
    for (final (amount, code) in [(5.5, 'OMR'), (300.0, 'INR')]) {
      expect(
        find.descendant(
          of: totals,
          matching: find.text(AppMoney.format(amount, currency: code)),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('an archived tab with a balance is listed with a notice', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(payLaterTab('old', name: 'Old shop').copyWith(isArchived: true))
      ..add(payLaterTab('done', name: 'Closed').copyWith(isArchived: true));
    ledger.purchases['old'] = [purchase('a', 3, DateTime(2026, 10, 2))];

    await pump(tester);

    expect(find.text('Archived, has a balance'), findsOneWidget);
    expect(
      find.text(
        'Old shop is archived but still owes money. It counts in your totals '
        'until settled.',
      ),
      findsOneWidget,
    );
    expect(tile('old'), findsOneWidget);
    // Archived and settled: folded away until asked for.
    expect(tile('done'), findsNothing);
    await tapVisible(tester, find.text('Archived tabs'));
    expect(tile('done'), findsOneWidget);
  });

  testWidgets('the archived notice agrees with several owing tabs', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('old', name: 'Old shop').copyWith(isArchived: true))
      ..add(payLaterTab('bak', name: 'Bakery').copyWith(isArchived: true));
    ledger.purchases['old'] = [purchase('a', 3, DateTime(2026, 10, 2))];
    ledger.purchases['bak'] = [purchase('b', 1, DateTime(2026, 10, 2))];

    await pump(tester);

    expect(
      find.text(
        'Bakery and Old shop are archived but still owe money. They count in '
        'your totals until settled.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an archived tab only in credit is not said to count in totals', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(payLaterTab('zed', name: 'Zed').copyWith(isArchived: true));
    ledger.purchases['zed'] = [purchase('a', 1, DateTime(2026, 10, 2))];
    ledger.payments['zed'] = [payment('p', 'zed', 3, DateTime(2026, 10, 3))];

    await pump(tester);

    expect(find.text('Archived, has a balance'), findsOneWidget);
    expect(
      find.text('Zed is archived but holds credit, so it stays listed here.'),
      findsOneWidget,
    );
    expect(find.textContaining('counts in your totals'), findsNothing);
    expect(tile('zed'), findsOneWidget);
  });

  testWidgets('the archived notice names owing and credit tabs apart', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('old', name: 'Old shop').copyWith(isArchived: true))
      ..add(payLaterTab('zed', name: 'Zed').copyWith(isArchived: true));
    ledger.purchases['old'] = [purchase('a', 3, DateTime(2026, 10, 2))];
    ledger.payments['zed'] = [payment('p', 'zed', 3, DateTime(2026, 10, 3))];

    await pump(tester);

    expect(
      find.text(
        'Old shop is archived but still owes money. It counts in your totals '
        'until settled. Zed is archived but holds credit, so it stays listed '
        'here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a tab opens its detail', (tester) async {
    tabs.add(payLaterTab('t1'));

    await pump(tester);
    await tapVisible(tester, tile('t1'));

    expect(find.text('Tab detail t1'), findsOneWidget);
  });

  testWidgets('add to a tab with one active tab opens the expense form on it', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(payLaterTab('old', name: 'Old').copyWith(isArchived: true));

    await pump(tester);
    await tester.tap(find.text('Add to a tab'));
    await tester.pumpAndSettle();

    expect(find.text('Add expense t1'), findsOneWidget);
  });

  testWidgets('add to a tab with several tabs asks which first', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(payLaterTab('t2', name: 'Bakery'));

    await pump(tester);
    await tester.tap(find.text('Add to a tab'));
    await tester.pumpAndSettle();
    expect(find.text('Add to which tab?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pickTab_t2')));
    await tester.pumpAndSettle();

    expect(find.text('Add expense t2'), findsOneWidget);
  });

  Finder fabLabelled(String label) => find.descendant(
    of: find.byType(FloatingActionButton),
    matching: find.text(label),
  );

  testWidgets('with only archived tabs the button is New tab', (tester) async {
    tabs.add(payLaterTab('old', name: 'Old').copyWith(isArchived: true));

    await pump(tester);
    expect(find.text('Add to a tab'), findsNothing);
    await tester.tap(fabLabelled('New tab'));
    await tester.pumpAndSettle();

    expect(find.text('New tab form'), findsOneWidget);
  });

  testWidgets('with an active tab the button is Add to a tab', (tester) async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(payLaterTab('old', name: 'Old').copyWith(isArchived: true));

    await pump(tester);

    expect(fabLabelled('Add to a tab'), findsOneWidget);
    expect(fabLabelled('New tab'), findsNothing);
  });

  testWidgets('new tab opens the tab form', (tester) async {
    tabs.add(payLaterTab('t1'));

    await pump(tester);
    await tester.tap(find.byKey(const Key('payLaterNewTabButton')));
    await tester.pumpAndSettle();

    expect(find.text('New tab form'), findsOneWidget);
  });

  testWidgets('record payment with one tab owing opens that tab', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(payLaterTab('t2', name: 'Bakery'));
    ledger.purchases['t2'] = [purchase('a', 1, DateTime(2026, 11, 1))];

    await pump(tester);
    await tapVisible(
      tester,
      find.byKey(const Key('payLaterRecordPaymentButton')),
    );

    expect(find.text('Tab detail t2'), findsOneWidget);
  });

  testWidgets('record payment with several tabs owing asks which', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('t1'))
      ..add(payLaterTab('t2', name: 'Bakery'))
      ..add(payLaterTab('t3', name: 'Settled shop'));
    ledger.purchases['t1'] = [purchase('a', 1, DateTime(2026, 11, 1))];
    ledger.purchases['t2'] = [purchase('b', 1, DateTime(2026, 11, 1))];

    await pump(tester);
    await tapVisible(
      tester,
      find.byKey(const Key('payLaterRecordPaymentButton')),
    );
    expect(find.text('Pay which tab?'), findsOneWidget);
    // Only tabs that owe are offered.
    expect(find.byKey(const Key('pickTab_t3')), findsNothing);
    await tester.tap(find.byKey(const Key('pickTab_t1')));
    await tester.pumpAndSettle();

    expect(find.text('Tab detail t1'), findsOneWidget);
  });

  testWidgets('no record payment while nothing is owed', (tester) async {
    tabs.add(payLaterTab('t1'));

    await pump(tester);

    expect(find.byKey(const Key('payLaterRecordPaymentButton')), findsNothing);
  });

  testWidgets('currency switcher only when tabs span currencies', (
    tester,
  ) async {
    tabs.add(payLaterTab('omr'));
    ledger.purchases['omr'] = [purchase('a', 1, DateTime(2026, 11, 1))];
    await pump(tester);
    await scrollTo(tester, find.text('Owed at month end'));
    expect(find.byKey(const Key('payLaterCurrencySwitcher')), findsNothing);
  });

  testWidgets('switching currency shows that currency in the charts', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('omr'))
      ..add(payLaterTab('inr', name: 'Kirana', currency: 'INR'));
    ledger.purchases['omr'] = [purchase('a', 1, DateTime(2026, 11, 1))];
    ledger.purchases['inr'] = [purchase('b', 300, DateTime(2026, 11, 1))];

    final bloc = await pump(tester);
    await scrollTo(tester, find.byKey(const Key('payLaterCurrencySwitcher')));
    expect(find.byKey(const Key('payLaterCurrencySwitcher')), findsOneWidget);
    expect(bloc.state.analytics?.currency, 'OMR');

    await tapVisible(tester, find.byKey(const Key('payLaterCurrency_INR')));

    expect(bloc.state.currency, 'INR');
    expect(bloc.state.analytics?.currency, 'INR');
    expect(bloc.state.analytics?.months.last.added, 300);
  });

  testWidgets('charts show added vs paid and owed over time', (tester) async {
    tabs.add(payLaterTab('t1'));
    ledger.purchases['t1'] = [
      purchase('a', 2, DateTime(2026, 10, 5)),
      purchase('b', 1, DateTime(2026, 11, 1)),
    ];
    ledger.payments['t1'] = [payment('p', 't1', 1.5, DateTime(2026, 10, 20))];

    await pump(tester);
    await scrollTo(tester, find.byType(LineChart));

    expect(find.text('Added and paid'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Owed at month end'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('owed chart ticks are round numbers with a label at the top', (
    tester,
  ) async {
    tabs.add(payLaterTab('t1'));
    ledger.purchases['t1'] = [
      purchase('a', 2, DateTime(2026, 10, 5)),
      purchase('b', 0.33, DateTime(2026, 11, 1)),
    ];

    await pump(tester);
    await scrollTo(tester, find.byType(LineChart));

    // Owed at the end of Nov is 2.33: ticks every 1, up to 3.
    Finder axis(String label) =>
        find.descendant(of: find.byType(LineChart), matching: find.text(label));
    for (final label in ['0', '1', '2', '3']) {
      expect(axis(label), findsOneWidget, reason: label);
    }
    expect(axis('2.33'), findsNothing);
  });

  group('settle-up wording (QA F4)', () {
    // Periods start 26 Oct, 2 Nov, 9 Nov: 2 Nov is a settle-up day.
    final onToday = EveryDays(days: 7, anchor: DateTime(2026, 10, 26));
    // Periods start 27 Oct, 3 Nov: the settle-up day is tomorrow.
    final onTomorrow = EveryDays(days: 7, anchor: DateTime(2026, 10, 27));

    testWidgets('header and tile say today on the settle-up day', (
      tester,
    ) async {
      tabs.add(payLaterTab('t1', rhythm: onToday));
      ledger.purchases['t1'] = [purchase('a', 1, DateTime(2026, 10, 27))];

      await pump(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('payLaterTotals')),
          matching: find.textContaining('Next settle-up today'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile('t1'),
          matching: find.textContaining('Settle up today'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('2 Nov'), findsNothing);
    });

    testWidgets('header and tile say tomorrow the day before', (tester) async {
      tabs.add(payLaterTab('t1', rhythm: onTomorrow));
      ledger.purchases['t1'] = [purchase('a', 1, DateTime(2026, 11, 1))];

      await pump(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('payLaterTotals')),
          matching: find.textContaining('Next settle-up tomorrow'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile('t1'),
          matching: find.textContaining('Settle up tomorrow'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tab in credit or settled shows no settle-up day', (
      tester,
    ) async {
      tabs
        ..add(payLaterTab('credit', name: 'Credit', rhythm: onToday))
        ..add(payLaterTab('settled', name: 'Settled', rhythm: onToday));
      ledger.purchases['credit'] = [purchase('a', 1, DateTime(2026, 10, 27))];
      ledger.payments['credit'] = [
        payment('p1', 'credit', 1.5, DateTime(2026, 10, 28)),
      ];
      ledger.purchases['settled'] = [purchase('b', 1, DateTime(2026, 10, 27))];
      ledger.payments['settled'] = [
        payment('p2', 'settled', 1, DateTime(2026, 10, 28)),
      ];

      await pump(tester);

      for (final id in ['credit', 'settled']) {
        expect(
          find.descendant(
            of: tile(id),
            matching: find.textContaining('Settle up'),
          ),
          findsNothing,
          reason: id,
        );
      }
      expect(find.textContaining('Next settle-up'), findsNothing);
    });
  });

  testWidgets('recent purchases show five and see all shows the rest', (
    tester,
  ) async {
    tabs.add(payLaterTab('t1'));
    ledger.purchases['t1'] = [
      for (var day = 1; day <= 7; day++)
        purchase('e$day', 1, DateTime(2026, 10, day)),
    ];

    await pump(tester);
    final seeAll = find.byKey(const Key('recentPurchasesSeeAll'));
    await tester.ensureVisible(seeAll);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recentPurchase_e7')), findsOneWidget);
    expect(find.byKey(const Key('recentPurchase_e2')), findsNothing);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recentPurchase_e2')), findsOneWidget);
    expect(find.byKey(const Key('recentPurchase_e1')), findsOneWidget);
  });

  testWidgets('a load failure offers try again', (tester) async {
    tabs.add(payLaterTab('t1'));
    getTabs.fail = true;

    await pump(tester);

    expect(find.byType(StatusCard), findsOneWidget);
    expect(find.text("Couldn't load your tabs."), findsOneWidget);
    getTabs.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(tile('t1'), findsOneWidget);
  });

  testWidgets('reloads when pay later changes elsewhere', (tester) async {
    tabs.add(payLaterTab('t1'));
    await pump(tester);
    expect(tile('t2'), findsNothing);

    tabs.add(payLaterTab('t2', name: 'Bakery'));
    RefreshBuses.payLater.notifyChanged();
    await tester.pumpAndSettle();

    expect(tile('t2'), findsOneWidget);
  });

  testWidgets('reloads when an expense changes', (tester) async {
    tabs.add(payLaterTab('t1'));
    await pump(tester);

    ledger.purchases['t1'] = [purchase('a', 2, DateTime(2026, 11, 1))];
    RefreshBuses.expenses.notifyChanged();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: tile('t1'),
        matching: find.text(AppMoney.format(2, currency: 'OMR')),
      ),
      findsOneWidget,
    );
  });

  group('every surface words the same settle-up day, for every rhythm', () {
    // The overview header and Home row word `overview.upcoming` against
    // `overview.today`; the tab tile and tab detail header use
    // `TabTile.settleUpLine(ledger)` (against `ledger.asOf`); a period card
    // uses `PeriodGroup.settleLine` against the screen's day. The widget
    // tests above pin each surface to these calls; this pins that they
    // agree for each rhythm on the day before, the day and the day after.
    final cases = <String, (SettleRhythm, DateTime, DateTime?)>{
      'every 7 days': (
        EveryDays(days: 7, anchor: DateTime(2026, 10, 26)),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 9),
      ),
      'monthly day 31 in February': (
        const MonthlyDay(day: 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
      ),
      'monthly day 31 in a 30-day month': (
        const MonthlyDay(day: 31),
        DateTime(2027, 4, 30),
        DateTime(2027, 5, 31),
      ),
      'monthly day 30 in a leap-year February': (
        const MonthlyDay(day: 30),
        DateTime(2028, 2, 29),
        DateTime(2028, 3, 30),
      ),
      'pick a date': (
        ManualDate(
          anchor: DateTime(2026, 11, 1),
          nextSettleDate: DateTime(2026, 11, 30),
        ),
        DateTime(2026, 11, 30),
        null,
      ),
    };

    /// What each surface shows for tab `t1` at 10:00 on [day].
    Future<
      ({
        String? tile,
        String? header,
        String? homeRow,
        String period,
        bool overdue,
      })
    >
    surfacesOn(DateTime day, {bool paid = false}) async {
      final clock = DateTime(day.year, day.month, day.day, 10);
      final getLedger = FakeGetTabLedgerUseCase(tabs: tabs, clock: () => clock)
        ..purchases['t1'] = ledger.purchases['t1']!;
      if (paid) {
        getLedger.payments['t1'] = [payment('p1', 't1', 1.5, day)];
      }
      final result = await GetPayLaterOverviewUseCase(
        getTabs: getTabs,
        getLedger: getLedger,
        clock: () => clock,
      )();
      final overview = (result as PayLaterSuccess<PayLaterOverview>).data;
      final tabLedger = overview.tabs.single;
      expect(tabLedger.asOf, overview.today, reason: 'one "today"');
      final next = overview.upcoming.firstOrNull;
      final home = overview.upcoming
          .where((u) => u.$1.currency == 'OMR')
          .firstOrNull;
      return (
        tile: TabTile.settleUpLine(tabLedger),
        header: next == null
            ? null
            : 'Next settle-up '
                  '${TabTile.relativeDay(next.$2, today: overview.today)}',
        homeRow: home == null
            ? null
            : 'Next settle-up '
                  '${TabTile.relativeDay(home.$2, today: overview.today)}',
        period: PeriodGroup.settleLine(
          tabLedger.purchases.single.period!,
          overview.today,
        ),
        overdue: tabLedger.overdue > 0,
      );
    }

    for (final MapEntry(key: name, value: (rhythm, settleUp, following))
        in cases.entries) {
      test(name, () async {
        tabs.add(payLaterTab('t1', rhythm: rhythm));
        // Bought on the last day of the period settling on [settleUp].
        ledger.purchases['t1'] = [purchase('a', 1.5, settleUp.addDays(-1))];
        final settleDay = TabTile.formatDay(settleUp, today: settleUp);

        final before = await surfacesOn(settleUp.addDays(-1));
        expect(before.tile, 'Settle up tomorrow');
        expect(before.header, 'Next settle-up tomorrow');
        expect(before.homeRow, before.header);
        expect(before.period, 'Settle up tomorrow');
        expect(before.overdue, isFalse);

        final on = await surfacesOn(settleUp);
        expect(on.tile, 'Settle up today');
        expect(on.header, 'Next settle-up today');
        expect(on.homeRow, on.header);
        expect(on.period, 'Settle up today');
        expect(on.overdue, isFalse);

        final after = await surfacesOn(settleUp.addDays(1));
        expect(after.overdue, isTrue);
        expect(after.period, 'Settle-up was $settleDay');
        if (following == null) {
          // The tile and detail ask for a date instead.
          expect(after.tile, isNull);
          expect(after.header, isNull);
          expect(after.homeRow, isNull);
        } else {
          final day = TabTile.relativeDay(
            following,
            today: settleUp.addDays(1),
          );
          expect(after.tile, 'Settle up $day');
          expect(after.header, 'Next settle-up $day');
          expect(after.homeRow, after.header);
        }

        // Owing nothing hides the line everywhere, even on the day.
        final settled = await surfacesOn(settleUp, paid: true);
        expect(settled.tile, isNull);
        expect(settled.header, isNull);
        expect(settled.homeRow, isNull);
      });
    }
  });
}
