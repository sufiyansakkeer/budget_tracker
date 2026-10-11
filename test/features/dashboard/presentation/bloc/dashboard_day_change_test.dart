import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';

import '../../../../integration/app_harness.dart';

/// UX-001: an app left open overnight showed yesterday's Today's Safe
/// Spending and "Spent today" until data changed. A new calendar day
/// (RefreshBuses.day) now reloads the dashboard for the new date.
void main() {
  late AppHarness app;
  late DashboardBloc bloc;
  late DateTime now;

  setUp(() async {
    app = await AppHarness.create();
    now = DateTime(2026, 8, 10, 22, 0);
    bloc = app.dashboardBloc(clock: () => now);
  });

  tearDown(() async {
    await bloc.close();
    await app.dispose();
  });

  Future<DashboardLoaded> loaded({
    bool Function(DashboardLoaded s)? where,
  }) async =>
      await bloc.stream.firstWhere(
            (s) => s is DashboardLoaded && (where?.call(s) ?? true),
          )
          as DashboardLoaded;

  test('the day bus reloads Home for the new date: yesterday\'s spending '
      'leaves "today" and the remaining days drop by one', () async {
    await app.addBudget(
      id: 'aug',
      name: 'August',
      amount: 22000,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
    );
    await app.expenseRepository.createExpense(
      ExpenseEntity(
        id: 'dinner',
        budgetId: 'aug',
        amount: 300,
        categoryId: 'food',
        date: DateTime(2026, 8, 10),
        time: DateTime(2026, 8, 10, 20),
        createdAt: DateTime(2026, 8, 10, 20),
        updatedAt: DateTime(2026, 8, 10, 20),
      ),
    );

    bloc.add(const DashboardLoadData());
    final evening = (await loaded()).activeSafeToSpend!;
    expect(evening.today, DateTime(2026, 8, 10));
    expect(evening.todayDiscretionary, 300);
    expect(evening.remainingDays, 22);

    // The app stays in memory overnight; nothing else changes.
    now = DateTime(2026, 8, 11, 7, 30);
    RefreshBuses.day.notifyChanged();
    final morning = (await loaded(
      where: (s) => s.activeSafeToSpend?.today == DateTime(2026, 8, 11),
    )).activeSafeToSpend!;

    expect(morning.todayDiscretionary, 0);
    expect(morning.remainingDays, 21);
    // Worked out again from what is left: (22,000 − 300) ÷ 21.
    expect(morning.dailySafeToSpend, closeTo(21700 / 21, 1e-9));
  });
}
