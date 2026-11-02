import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/core/router/app_router.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_overview_usecase.dart';
import 'package:monivo/features/pay_later/presentation/bloc/pay_later_summary_cubit.dart';
import 'package:monivo/features/pay_later/presentation/widgets/pay_later_home_row.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_state.dart';

import '../../../helpers/pay_later_fakes.dart';
import '../../../helpers/pay_later_fixtures.dart';
import '../../settings/presentation/pages/settings_test_harness.dart';
import 'pay_later_overview_screen_test.dart' show payment, purchase;

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

  PayLaterSummaryCubit makeCubit({DateTime Function()? clock}) {
    final cubit = PayLaterSummaryCubit(
      getOverview: GetPayLaterOverviewUseCase(
        getTabs: getTabs,
        getLedger: ledger,
        clock: clock ?? () => now,
      ),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<PayLaterSummaryCubit> pumpRow(
    WidgetTester tester, {
    DateTime Function()? clock,
  }) async {
    final cubit = makeCubit(clock: clock);
    await cubit.load();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const Column(
                children: [Text('above'), PayLaterHomeRow(), Text('below')],
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRouter.payLaterPath,
          builder: (_, _) => const Scaffold(body: Text('Pay later overview')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('home row hidden with no tabs', (tester) async {
    await pumpRow(tester);

    expect(find.byKey(const Key('payLaterHomeRow')), findsNothing);
    expect(find.text('Pay later'), findsNothing);
    // It takes no space: the neighbours touch.
    expect(
      tester.getBottomLeft(find.text('above')).dy,
      tester.getTopLeft(find.text('below')).dy,
    );
  });

  testWidgets('home row hidden when the summary cannot be read', (
    tester,
  ) async {
    tabs.add(payLaterTab('t1'));
    getTabs.fail = true;

    await pumpRow(tester);

    expect(find.byKey(const Key('payLaterHomeRow')), findsNothing);
  });

  testWidgets('home row shows owed per currency and next settle-up', (
    tester,
  ) async {
    tabs
      ..add(payLaterTab('omr', rhythm: weekly))
      ..add(payLaterTab('inr', name: 'Kirana', currency: 'INR'));
    // 1 Nov settles on 5 Nov; the INR tab is on demand.
    ledger.purchases['omr'] = [purchase('a', 4.5, DateTime(2026, 11, 1))];
    ledger.purchases['inr'] = [purchase('b', 300, DateTime(2026, 11, 1))];

    await pumpRow(tester);

    expect(find.text('Pay later'), findsOneWidget);
    expect(find.text(AppMoney.format(4.5, currency: 'OMR')), findsOneWidget);
    expect(find.text(AppMoney.format(300, currency: 'INR')), findsOneWidget);
    expect(find.text('Next settle-up 5 Nov'), findsOneWidget);
    // Never one figure across currencies.
    expect(find.text(AppMoney.format(304.5, currency: 'OMR')), findsNothing);
  });

  testWidgets('settle-up on the current day reads today, overdue is named', (
    tester,
  ) async {
    tabs.add(
      payLaterTab(
        't1',
        rhythm: EveryDays(days: 2, anchor: DateTime(2026, 10, 31)),
      ),
    );
    // Bought 31 Oct, settles on 2 Nov (today); one from 1 Oct is overdue.
    ledger.purchases['t1'] = [
      purchase('old', 3, DateTime(2026, 10, 1)),
      purchase('new', 1, DateTime(2026, 10, 31)),
    ];

    await pumpRow(tester);

    expect(find.textContaining('overdue'), findsWidgets);
    expect(find.textContaining('Next settle-up today'), findsOneWidget);
  });

  testWidgets('settle-up on the next day reads tomorrow', (tester) async {
    // Periods start 27 Oct, 3 Nov: bought 1 Nov, settles tomorrow.
    tabs.add(
      payLaterTab(
        't1',
        rhythm: EveryDays(days: 7, anchor: DateTime(2026, 10, 27)),
      ),
    );
    ledger.purchases['t1'] = [purchase('a', 1, DateTime(2026, 11, 1))];

    await pumpRow(tester);

    expect(find.text('Next settle-up tomorrow'), findsOneWidget);
  });

  testWidgets('a new day turns tomorrow into today with no write (M1)', (
    tester,
  ) async {
    var day = now;
    tabs.add(
      payLaterTab(
        't1',
        rhythm: EveryDays(days: 7, anchor: DateTime(2026, 10, 27)),
      ),
    );
    ledger = FakeGetTabLedgerUseCase(tabs: tabs, clock: () => day);
    ledger.purchases['t1'] = [purchase('a', 1, DateTime(2026, 11, 1))];
    await pumpRow(tester, clock: () => day);
    expect(find.text('Next settle-up tomorrow'), findsOneWidget);

    // Midnight: the settle-up day (3 Nov) is the same date, only "today"
    // moved.
    day = DateTime(2026, 11, 3, 0, 1);
    RefreshBuses.day.notifyChanged();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('Next settle-up today'), findsOneWidget);
    expect(find.textContaining('tomorrow'), findsNothing);
  });

  testWidgets('a tab in credit shows no settle-up day', (tester) async {
    tabs.add(
      payLaterTab(
        't1',
        rhythm: EveryDays(days: 7, anchor: DateTime(2026, 10, 26)),
      ),
    );
    ledger.purchases['t1'] = [purchase('a', 1, DateTime(2026, 10, 27))];
    ledger.payments['t1'] = [payment('p', 't1', 1.5, DateTime(2026, 10, 28))];

    await pumpRow(tester);

    expect(find.text('Nothing owed'), findsOneWidget);
    expect(find.textContaining('settle-up'), findsNothing);
  });

  testWidgets('an archived tab with a balance still shows the row', (
    tester,
  ) async {
    tabs.add(payLaterTab('t1').copyWith(isArchived: true));
    ledger.purchases['t1'] = [purchase('a', 2, DateTime(2026, 10, 20))];

    await pumpRow(tester);

    expect(find.byKey(const Key('payLaterHomeRow')), findsOneWidget);
    expect(find.text(AppMoney.format(2, currency: 'OMR')), findsOneWidget);
  });

  testWidgets('an archived tab with nothing owed keeps the row hidden', (
    tester,
  ) async {
    tabs.add(payLaterTab('t1').copyWith(isArchived: true));

    await pumpRow(tester);

    expect(find.byKey(const Key('payLaterHomeRow')), findsNothing);
  });

  testWidgets('an active tab with nothing owed says so', (tester) async {
    tabs.add(payLaterTab('t1'));

    await pumpRow(tester);

    expect(find.text('Nothing owed'), findsOneWidget);
  });

  testWidgets('tapping the row opens the overview', (tester) async {
    tabs.add(payLaterTab('t1'));
    ledger.purchases['t1'] = [purchase('a', 2, DateTime(2026, 10, 20))];
    await pumpRow(tester);

    await tester.tap(find.byKey(const ValueKey('payLaterHome_OMR')));
    await tester.pumpAndSettle();

    expect(find.text('Pay later overview'), findsOneWidget);
  });

  testWidgets('the row follows tab changes announced on the bus', (
    tester,
  ) async {
    final cubit = await pumpRow(tester);
    expect(find.byKey(const Key('payLaterHomeRow')), findsNothing);

    tabs.add(payLaterTab('t1'));
    RefreshBuses.payLater.notifyChanged();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(cubit.state, isNotNull);
    expect(find.byKey(const Key('payLaterHomeRow')), findsOneWidget);
  });

  testWidgets('a failed reload keeps what is shown', (tester) async {
    tabs.add(payLaterTab('t1'));
    final cubit = await pumpRow(tester);
    expect(find.byKey(const Key('payLaterHomeRow')), findsOneWidget);

    getTabs.fail = true;
    await cubit.load();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('payLaterHomeRow')), findsOneWidget);
  });

  testWidgets('settings row opens pay later', (tester) async {
    await setUpSettingsScreen();
    addTearDown(() => getIt.reset());
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 9000);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => settingsScreen(
            settings: StaticSettingsBloc(loadedSettings),
            theme: StaticThemeBloc(const ThemeState()),
          ),
        ),
        GoRoute(
          path: AppRouter.payLaterPath,
          builder: (_, _) => const Scaffold(body: Text('Pay later overview')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const Key('settingsPayLaterTile'));
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('Pay later overview'), findsOneWidget);
  });
}
