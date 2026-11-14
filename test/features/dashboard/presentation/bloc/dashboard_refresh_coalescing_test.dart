import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';

import '../../../../integration/app_harness.dart';

/// UX-065: paying a bill notifies the bills and expenses buses back to
/// back, and an import or restore notifies three, so Home re-read
/// everything two or three times for one change.
void main() {
  late AppHarness app;
  late DashboardBloc bloc;
  var loads = 0;

  setUp(() async {
    app = await AppHarness.create();
    loads = 0;
    // The clock is read once per load.
    bloc = app.dashboardBloc(
      clock: () {
        loads++;
        return DateTime(2026, 8, 10, 9);
      },
    );
    await app.addBudget(
      id: 'aug',
      name: 'August',
      amount: 22000,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
    );
    bloc.add(const DashboardLoadData());
    await bloc.stream.firstWhere((s) => s is DashboardLoaded);
    loads = 0;
  });

  tearDown(() async {
    await bloc.close();
    await app.dispose();
  });

  test('a bill payment (bills and expenses buses) reloads Home once', () async {
    RefreshBuses.bills.notifyChanged();
    RefreshBuses.expenses.notifyChanged();
    await pumpEventQueue();
    expect(loads, 1);
  });

  test('an import or restore (three buses) reloads Home once', () async {
    RefreshBuses.budgets.notifyChanged();
    RefreshBuses.expenses.notifyChanged();
    RefreshBuses.bills.notifyChanged();
    await pumpEventQueue();
    expect(loads, 1);
  });

  test('separate changes still reload each time', () async {
    RefreshBuses.expenses.notifyChanged();
    await pumpEventQueue();
    RefreshBuses.expenses.notifyChanged();
    await pumpEventQueue();
    expect(loads, 2);
  });
}
