import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_analytics_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_overview_usecase.dart';
import 'package:monivo/features/pay_later/presentation/bloc/pay_later_overview_bloc.dart';
import 'package:monivo/features/pay_later/presentation/bloc/pay_later_overview_event.dart';
import 'package:monivo/features/pay_later/presentation/bloc/pay_later_overview_state.dart';

import '../../../helpers/pay_later_fakes.dart';
import '../../../helpers/pay_later_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 2, 10);
  late List<PayLaterTab> tabs;
  late FakeGetTabsUseCase getTabs;
  late PayLaterOverviewBloc bloc;

  setUp(() {
    tabs = [payLaterTab('t1')];
    getTabs = FakeGetTabsUseCase(tabs);
    final ledger = FakeGetTabLedgerUseCase(tabs: tabs, clock: () => now);
    bloc = PayLaterOverviewBloc(
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
  });

  tearDown(() => bloc.close());

  Future<PayLaterOverviewState> loaded() => bloc.stream.firstWhere(
    (s) =>
        s.status == PayLaterOverviewStatus.loaded &&
        s.analyticsStatus != PayLaterAnalyticsStatus.loading,
  );

  test('loads the overview and the first currency charts', () async {
    bloc.add(const PayLaterOverviewStarted());
    final state = await loaded();

    expect(state.overview?.tabs.single.tab.id, 't1');
    expect(state.currency, 'OMR');
    expect(state.analytics?.currency, 'OMR');
  });

  for (final (name, bus) in [
    ('payLater', RefreshBuses.payLater),
    ('expenses', RefreshBuses.expenses),
    ('day', RefreshBuses.day),
  ]) {
    test('reloads when the $name bus fires', () async {
      bloc.add(const PayLaterOverviewStarted());
      await loaded();
      final before = getTabs.calls;

      bus.notifyChanged();
      await pumpEventQueue();

      expect(getTabs.calls, greaterThan(before));
    });
  }

  test('a refresh keeps what is shown (no loading flash)', () async {
    bloc.add(const PayLaterOverviewStarted());
    await loaded();
    final statuses = <PayLaterOverviewStatus>[];
    final sub = bloc.stream.listen((s) => statuses.add(s.status));

    bloc.add(const PayLaterOverviewRefreshed());
    await pumpEventQueue();
    await sub.cancel();

    expect(statuses, isNot(contains(PayLaterOverviewStatus.loading)));
  });

  test('a failed refresh keeps the last overview', () async {
    bloc.add(const PayLaterOverviewStarted());
    await loaded();
    getTabs.fail = true;

    bloc.add(const PayLaterOverviewRefreshed());
    await pumpEventQueue();

    expect(bloc.state.status, PayLaterOverviewStatus.loaded);
    expect(bloc.state.overview?.tabs, hasLength(1));
  });

  test('a failed first load is an error with copy for people', () async {
    getTabs.fail = true;

    bloc.add(const PayLaterOverviewStarted());
    final state = await bloc.stream.firstWhere(
      (s) => s.status == PayLaterOverviewStatus.error,
    );

    expect(state.errorMessage, PayLaterOverviewBloc.loadFailedMessage);
    expect(state.errorMessage, isNot(contains('disk I/O')));
  });

  test('stops listening once closed', () async {
    bloc.add(const PayLaterOverviewStarted());
    await loaded();
    await bloc.close();
    final before = getTabs.calls;

    RefreshBuses.payLater.notifyChanged();
    await pumpEventQueue();

    expect(getTabs.calls, before);
  });
}
