import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';

import '../../../../integration/app_harness.dart';

/// DashboardBloc on the real engine and repositories with a fixed clock:
/// the active budget's Today's Safe Spending follows budget switches and
/// bill and expense changes, and a budget that is not running gets its own
/// state instead of an error.
void main() {
  late AppHarness app;
  late DashboardBloc bloc;

  /// 10 Aug 2026 evening: Aug 10–31 is 22 days including today.
  final clock = DateTime(2026, 8, 10, 18, 0);
  final today = DateTime(2026, 8, 10);
  const remainingDays = 22;

  setUp(() async {
    app = await AppHarness.create();
    bloc = app.dashboardBloc(clock: () => clock);
  });

  tearDown(() async {
    await bloc.close();
    await app.dispose();
  });

  Future<void> addAugust(String id, double amount, {bool active = true}) =>
      app.addBudget(
        id: id,
        name: 'Budget $id',
        amount: amount,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
        makeActive: active,
      );

  Future<DashboardLoaded> loaded({
    bool Function(DashboardLoaded s)? where,
  }) async =>
      await bloc.stream.firstWhere(
            (s) => s is DashboardLoaded && (where?.call(s) ?? true),
          )
          as DashboardLoaded;

  test('the active budget\'s entity drives the hero and follows a budget '
      'switch (budgets bus)', () async {
    await addAugust('food', 22000, active: false);
    await addAugust('trip', 11000);

    bloc.add(const DashboardLoadData());
    final first = await loaded();
    expect(first.activeBudgetId, 'trip');
    expect(first.activeSafeToSpend!.budgetId, 'trip');
    expect(first.activeSafeToSpend!.today, today);
    expect(first.activeBudgetLimit!.dailyLimit, closeTo(500, 1e-9));
    expect(
      first.otherBudgetLimits.single.safeToSpend!.dailySafeToSpend,
      closeTo(1000, 1e-9),
    );

    await app.budgetRepository.setActiveBudgetId('food');
    RefreshBuses.budgets.notifyChanged();
    final switched = await loaded(where: (s) => s.activeBudgetId == 'food');

    expect(switched.activeSafeToSpend!.budgetId, 'food');
    expect(switched.activeSafeToSpend!.dailySafeToSpend, closeTo(1000, 1e-9));
    expect(switched.budgetSummary.monthlyAmount, 22000);
    // Never pooled: the other budget keeps its own figure.
    expect(switched.otherBudgetLimits.single.budgetId, 'trip');
    expect(switched.otherBudgetLimits.single.dailyLimit, closeTo(500, 1e-9));
  });

  test('linking a bill lowers today\'s amount on the bills bus', () async {
    await addAugust('aug', 22000);
    bloc.add(const DashboardLoadData());
    final before = await loaded();
    expect(before.activeSafeToSpend!.dailySafeToSpend, closeTo(1000, 1e-9));

    await app.billRepository.createBill(
      BillEntity(
        id: 'rent',
        title: 'Rent',
        amount: 2200,
        currency: 'INR',
        category: BillCategory.rent,
        dueDate: DateTime(2026, 8, 20),
        budgetId: 'aug',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      ),
    );
    RefreshBuses.bills.notifyChanged();
    final after = await loaded(
      where: (s) => (s.activeSafeToSpend?.upcomingCommitments ?? 0) > 0,
    );

    expect(after.activeSafeToSpend!.upcomingCommitments, 2200);
    expect(
      after.activeSafeToSpend!.dailySafeToSpend,
      closeTo((22000 - 2200) / remainingDays, 1e-9),
    );
    expect(after.activeBudgetLimit!.dailyLimit, closeTo(900, 1e-9));
  });

  test('an expense today refreshes on the expenses bus; today\'s amount '
      'holds and what is left today drops', () async {
    await addAugust('aug', 22000);
    bloc.add(const DashboardLoadData());
    await loaded();

    await app.expenseRepository.createExpense(
      ExpenseEntity(
        id: 'coffee',
        budgetId: 'aug',
        amount: 300,
        categoryId: 'food',
        date: today,
        time: DateTime(2026, 8, 10, 9),
        createdAt: DateTime(2026, 8, 10, 9),
        updatedAt: DateTime(2026, 8, 10, 9),
      ),
    );
    RefreshBuses.expenses.notifyChanged();
    final after = await loaded(
      where: (s) => (s.activeSafeToSpend?.todaySpent ?? 0) > 0,
    );

    final entity = after.activeSafeToSpend!;
    expect(entity.todayDiscretionary, 300);
    expect(entity.dailySafeToSpend, closeTo(1000, 1e-9));
    expect(entity.remainingToday, closeTo(700, 1e-9));
    expect(after.budgetSummary.todaySpending, 300);
  });

  group('DashboardNotRunning', () {
    test('a budget that starts later shows its not-started result, with '
        'the bills it will set aside and the budgets running today', () async {
      await addAugust('aug', 22000, active: false);
      await app.addBudget(
        id: 'sep',
        name: 'September',
        amount: 30000,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      await app.billRepository.createBill(
        BillEntity(
          id: 'rent',
          title: 'Rent',
          amount: 12000,
          currency: 'INR',
          category: BillCategory.rent,
          dueDate: DateTime(2026, 9, 5),
          budgetId: 'sep',
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      );

      bloc.add(const DashboardLoadData());
      final state =
          await bloc.stream.firstWhere(
                (s) => s is! DashboardLoading && s is! DashboardInitial,
              )
              as DashboardNotRunning;

      expect(state.activeBudgetId, 'sep');
      expect(state.safeToSpend.status, SafeToSpendStatus.notStarted);
      expect(state.safeToSpend.today, today);
      expect(state.safeToSpend.dailySafeToSpend, 0);
      expect(state.safeToSpend.upcomingCommitments, 12000);
      expect(state.otherBudgetLimits.single.budgetId, 'aug');
    });

    test('an ended budget becomes running again after a switch, without '
        'an error in between', () async {
      await app.addBudget(
        id: 'jul',
        name: 'July',
        amount: 31000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 31),
      );
      await addAugust('aug', 22000, active: false);

      final states = <Object>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const DashboardLoadData());
      final ended =
          await bloc.stream.firstWhere((s) => s is DashboardNotRunning)
              as DashboardNotRunning;
      expect(ended.safeToSpend.status, SafeToSpendStatus.periodEnded);

      await app.budgetRepository.setActiveBudgetId('aug');
      RefreshBuses.budgets.notifyChanged();
      final running = await loaded();
      await sub.cancel();

      expect(running.activeSafeToSpend!.budgetId, 'aug');
      expect(states.whereType<DashboardError>(), isEmpty);
      expect(
        states.whereType<DashboardLoading>().length,
        1,
        reason: 'a refresh keeps the not-running content on screen',
      );
    });
  });
  test('an archived active budget is reported as archived, not as figures '
      'that failed to compute (review)', () async {
    await addAugust('food', 22000, active: false);
    await addAugust('aug', 22000);
    await app.budgetRepository.setBudgetArchived('aug', archived: true);

    bloc.add(const DashboardLoadData());
    final state = await loaded();

    expect(state.activeBudgetId, 'aug');
    expect(state.activeBudgetLimit, isNull);
    expect(state.activeBudgetArchived, isTrue);
    // The running budget keeps its figure.
    expect(state.otherBudgetLimits.single.budgetId, 'food');
  });

  test('a running budget whose figures exist is not marked archived', () async {
    await addAugust('aug', 22000);

    bloc.add(const DashboardLoadData());
    final state = await loaded();

    expect(state.activeBudgetLimit, isNotNull);
    expect(state.activeBudgetArchived, isFalse);
  });
}
