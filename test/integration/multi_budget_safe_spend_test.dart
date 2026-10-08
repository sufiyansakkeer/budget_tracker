import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_event.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_state.dart';

import 'app_harness.dart';

/// Two independent budgets with overlapping, different periods, through the
/// real repositories and SQL on an in-memory database:
///
/// - A "Household": ₹30,000, 1 → 31 Oct 2025
/// - B "Trip":      ₹15,000, 10 Oct → 10 Nov 2025
///
/// Each budget's Today's Safe Spending must come from its own expenses
/// inside its own period, its own bills, money kept aside and savings goal,
/// and its own remaining days — never from the other budget, even for
/// expenses dated inside both periods.
///
/// The fixture is in 2025 so expenses created through [ExpenseBloc] pass
/// its "not in the future" check whatever the real date is; every figure is
/// computed for the fixed reference date, never the real one.
void main() {
  late AppHarness app;
  late BudgetEntity trip;

  /// Wednesday 15 Oct 2025, evening.
  final clock = DateTime(2025, 10, 15, 18);
  final today = DateTime(2025, 10, 15);

  setUp(() async {
    app = await AppHarness.create();
    trip = await app.addBudget(
      id: 'b',
      name: 'Trip',
      amount: 15000,
      startDate: DateTime(2025, 10, 10),
      endDate: DateTime(2025, 11, 10),
      makeActive: false,
    );
    await app.addBudget(
      id: 'a',
      name: 'Household',
      amount: 30000,
      startDate: DateTime(2025, 10, 1),
      endDate: DateTime(2025, 10, 31),
    );
  });

  tearDown(() => app.dispose());

  Future<void> expense(
    String id,
    String budgetId,
    double amount,
    DateTime date,
  ) => app.expenseRepository.createExpense(
    ExpenseEntity(
      id: id,
      budgetId: budgetId,
      amount: amount,
      categoryId: 'food',
      date: date,
      time: date.add(const Duration(hours: 9)),
      createdAt: date,
      updatedAt: date,
    ),
  );

  /// A: ₹4,600 in its period (₹400 of it today).
  /// B: ₹2,500 in its period (₹500 of it today), plus ₹700 dated 5 Oct —
  /// before B starts but inside A's dates, so it belongs to neither total.
  Future<void> seedOctober() async {
    await expense('a-oct02', 'a', 3000, DateTime(2025, 10, 2));
    await expense('a-oct12', 'a', 1200, DateTime(2025, 10, 12));
    await expense('a-oct15', 'a', 400, DateTime(2025, 10, 15));
    await expense('b-oct05', 'b', 700, DateTime(2025, 10, 5));
    await expense('b-oct11', 'b', 2000, DateTime(2025, 10, 11));
    await expense('b-oct15', 'b', 500, DateTime(2025, 10, 15));
  }

  Future<SafeToSpendEntity> safeToSpend(String id, DateTime on) async {
    final result = await app.getSafeToSpend(budgetId: id, referenceDate: on);
    return (result as BudgetSuccess<SafeToSpendEntity>).data;
  }

  Future<Map<String, SafeToSpendEntity>> both(DateTime on) async {
    // Reload: setUp's entities predate any plan written by the test.
    final budgets = [
      (await app.budgetRepository.getBudgetById('a'))!,
      (await app.budgetRepository.getBudgetById('b'))!,
    ];
    return app.getSafeToSpend.callForBudgets(budgets, referenceDate: on);
  }

  Future<void> addBill(String id, double amount, DateTime due) =>
      app.billRepository.createBill(
        BillEntity(
          id: id,
          title: id,
          amount: amount,
          currency: 'INR',
          category: BillCategory.utilities,
          dueDate: due,
          budgetId: 'b',
          createdAt: DateTime(2025, 10, 1),
          updatedAt: DateTime(2025, 10, 1),
        ),
      );

  group('scoping', () {
    test('each budget sums only its own expenses inside its own period, '
        'even where the periods overlap', () async {
      await seedOctober();

      final results = await both(today);
      final a = results['a']!;
      final b = results['b']!;

      // A: 30,000 − 4,600 = 25,400 left; 15–31 Oct is 17 days.
      expect(a.periodSpent, 4600);
      expect(a.availableBalance, 25400);
      expect(a.todaySpent, 400);
      expect(a.daysPassed, 15);
      expect(a.remainingDays, 17);
      expect(a.dailySafeToSpend, closeTo(25800 / 17, 1e-9));
      expect(a.remainingToday, closeTo(25800 / 17 - 400, 1e-9));

      // B: 15,000 − 2,500 = 12,500 left; 15 Oct–10 Nov is 27 days. The
      // ₹700 dated before its start is not period spending.
      expect(b.periodSpent, 2500);
      expect(b.availableBalance, 12500);
      expect(b.todaySpent, 500);
      expect(b.daysPassed, 6);
      expect(b.remainingDays, 27);
      expect(b.dailySafeToSpend, closeTo(13000 / 27, 1e-9));
    });

    test("the budget summary agrees with the engine for the same budget "
        '(no deductions)', () async {
      await seedOctober();

      final summary =
          (await app.getBudgetSummary(budgetId: 'a', referenceDate: today)
                  as BudgetSuccess<BudgetSummaryEntity>)
              .data;
      final a = await safeToSpend('a', today);

      expect(summary.totalSpent, 4600);
      expect(summary.todaySpending, 400);
      expect(summary.remainingDays, a.remainingDays);
      expect(summary.dailySafeSpending, closeTo(a.dailySafeToSpend, 1e-9));
    });

    test("B's bills, kept-aside money and savings goal lower only B's "
        'amount; A is unchanged to the last field', () async {
      await seedOctober();
      final before = (await both(today))['a']!;

      await app.budgetRepository.updateBudget(
        trip.copyWith(reservedAmount: 1000, savingsTarget: 2000),
      );
      // One due inside both periods, one only inside B's.
      await addBill('internet', 1300, DateTime(2025, 10, 25));
      await addBill('insurance', 900, DateTime(2025, 11, 5));

      final results = await both(today);
      final a = results['a']!;
      final b = results['b']!;

      // B: 12,500 − 2,200 bills − 1,000 kept aside − 2,000 savings.
      expect(b.upcomingCommitments, 2200);
      expect(b.commitments.map((o) => o.billId), ['internet', 'insurance']);
      expect(b.reservedAmount, 1000);
      expect(b.remainingSavingsTarget, 2000);
      expect(b.rawSpendable, 7300);
      expect(b.dailySafeToSpend, closeTo(7800 / 27, 1e-9));

      // A never sees them: not deducted, not reported as unlinked.
      expect(a, before);
      expect(a.upcomingCommitments, 0);
      expect(a.commitments, isEmpty);
      expect(a.unlinked.isEmpty, isTrue);
      expect(a.reservedAmount, isNull);
      expect(a.savingsTarget, isNull);
      expect(a.dailySafeToSpend, closeTo(25800 / 17, 1e-9));
    });
  });

  group('periods', () {
    test('before B starts: B has no daily amount and its expense dated '
        "that day is not A's spending", () async {
      await expense('a-oct02', 'a', 3000, DateTime(2025, 10, 2));
      await expense('b-oct05', 'b', 700, DateTime(2025, 10, 5));
      final oct5 = DateTime(2025, 10, 5);

      final results = await both(oct5);
      final a = results['a']!;
      final b = results['b']!;

      // A: 27,000 left over 5–31 Oct (27 days), nothing of its own today.
      expect(a.status, isNot(SafeToSpendStatus.notStarted));
      expect(a.periodSpent, 3000);
      expect(a.todaySpent, 0);
      expect(a.remainingDays, 27);
      expect(a.dailySafeToSpend, closeTo(1000, 1e-9));

      expect(b.status, SafeToSpendStatus.notStarted);
      expect(b.daysUntilStart, 5);
      expect(b.periodSpent, 0);
      expect(b.todaySpent, 0);
      expect(b.dailySafeToSpend, 0);
      expect(b.remainingDays, b.totalDays);
      expect(b.totalDays, 32);

      final targets =
          await app.getSpendingTargets.callPerBudget(referenceDate: oct5)
              as PerBudgetSpendingTargetSuccess;
      expect(targets.budgetLimits.map((l) => l.budgetId), ['a']);
    });

    test("A's final day, then the month boundary: A ends with its own "
        'balance while B keeps running on its own figures', () async {
      await seedOctober();

      final oct31 = await both(DateTime(2025, 10, 31));
      // Final day: all that is left is today's (nothing spent on 31 Oct).
      expect(oct31['a']!.remainingDays, 1);
      expect(oct31['a']!.dailySafeToSpend, closeTo(25400, 1e-9));
      // 31 Oct–10 Nov is 11 days.
      expect(oct31['b']!.remainingDays, 11);
      expect(oct31['b']!.dailySafeToSpend, closeTo(12500 / 11, 1e-9));

      final nov1 = await both(DateTime(2025, 11, 1));
      final a = nov1['a']!;
      final b = nov1['b']!;

      expect(a.status, SafeToSpendStatus.periodEnded);
      expect(a.remainingDays, 0);
      expect(a.dailySafeToSpend, 0);
      expect(a.availableBalance, 25400);

      // 10 Oct–1 Nov is 23 days passed; 1–10 Nov is 10 left.
      expect(b.daysPassed, 23);
      expect(b.remainingDays, 10);
      expect(b.availableBalance, 12500);
      expect(b.dailySafeToSpend, closeTo(1250, 1e-9));

      final targets =
          await app.getSpendingTargets.callPerBudget(
                referenceDate: DateTime(2025, 11, 1),
              )
              as PerBudgetSpendingTargetSuccess;
      expect(targets.budgetLimits.map((l) => l.budgetId), ['b']);
      expect(targets.budgetLimits.single.dailyLimit, closeTo(1250, 1e-9));
    });
  });

  group('dashboard', () {
    late DashboardBloc dashboard;
    late ExpenseBloc expenses;

    setUp(() {
      dashboard = app.dashboardBloc(clock: () => clock);
      expenses = app.expenseBloc();
    });

    tearDown(() async {
      await expenses.close();
      await dashboard.close();
    });

    /// Subscribes before [trigger] runs, so a fast refresh cannot be missed.
    Future<DashboardLoaded> after(
      Future<void> Function() trigger, {
      required bool Function(DashboardLoaded s) where,
    }) async {
      final next = dashboard.stream.firstWhere(
        (s) => s is DashboardLoaded && where(s),
      );
      await trigger();
      return await next as DashboardLoaded;
    }

    BudgetDailyLimitEntity other(DashboardLoaded s) =>
        s.otherBudgetLimits.single;

    Future<void> run(ExpenseEvent event) async {
      final done = expenses.stream.firstWhere(
        (s) =>
            s.status == ExpenseBlocStatus.success ||
            s.status == ExpenseBlocStatus.error,
      );
      expenses.add(event);
      expect((await done).status, ExpenseBlocStatus.success);
    }

    test('switching the active budget swaps the hero to that budget; '
        'neither figure moves', () async {
      await seedOctober();

      final onA = await after(
        () async => dashboard.add(const DashboardLoadData()),
        where: (_) => true,
      );
      expect(onA.activeBudgetId, 'a');
      expect(
        onA.activeSafeToSpend!.dailySafeToSpend,
        closeTo(25800 / 17, 1e-9),
      );
      expect(onA.budgetSummary.totalSpent, 4600);
      expect(onA.budgetSummary.remainingDays, 17);
      expect(other(onA).budgetId, 'b');
      expect(other(onA).dailyLimit, closeTo(13000 / 27, 1e-9));

      final onB = await after(() async {
        await app.manageBudget.setActive('b');
        RefreshBuses.budgets.notifyChanged();
      }, where: (s) => s.activeBudgetId == 'b');
      expect(
        onB.activeSafeToSpend!.dailySafeToSpend,
        closeTo(13000 / 27, 1e-9),
      );
      expect(onB.budgetSummary.totalSpent, 2500);
      expect(onB.budgetSummary.remainingDays, 27);
      expect(other(onB).budgetId, 'a');
      expect(other(onB).safeToSpend, onA.activeSafeToSpend);

      final backOnA = await after(() async {
        await app.manageBudget.setActive('a');
        RefreshBuses.budgets.notifyChanged();
      }, where: (s) => s.activeBudgetId == 'a');
      expect(backOnA.activeSafeToSpend, onA.activeSafeToSpend);
      expect(other(backOnA).safeToSpend, onB.activeSafeToSpend);
    });

    test('expense changes update only the budget they belong to', () async {
      await seedOctober();
      final start = await after(
        () async => dashboard.add(const DashboardLoadData()),
        where: (_) => true,
      );
      final aStart = start.activeSafeToSpend!;

      // 1. ₹600 more in B today. Today's amount is fixed for the day, so
      //    B's daily holds and B goes over today; A is untouched.
      final s1 = await after(
        () => run(
          ExpenseCreate(
            ExpenseEntity(
              id: 'b-more',
              budgetId: 'b',
              amount: 600,
              categoryId: 'food',
              date: today,
              time: DateTime(2025, 10, 15, 13),
              createdAt: DateTime(2025, 10, 15, 13),
              updatedAt: DateTime(2025, 10, 15, 13),
            ),
          ),
        ),
        where: (s) => other(s).spentToday == 1100,
      );
      expect(s1.activeSafeToSpend, aStart);
      final b1 = other(s1).safeToSpend!;
      expect(b1.periodSpent, 3100);
      expect(b1.dailySafeToSpend, closeTo(13000 / 27, 1e-9));
      expect(b1.overToday, closeTo(1100 - 13000 / 27, 1e-9));
      expect(b1.status, SafeToSpendStatus.overDailyAllowance);

      // 2. ₹1,700 in A dated yesterday lowers A's daily; B is untouched.
      final s2 = await after(
        () => run(
          ExpenseCreate(
            ExpenseEntity(
              id: 'a-oct14',
              budgetId: 'a',
              amount: 1700,
              categoryId: 'food',
              date: DateTime(2025, 10, 14),
              time: DateTime(2025, 10, 14, 20),
              createdAt: DateTime(2025, 10, 14, 20),
              updatedAt: DateTime(2025, 10, 14, 20),
            ),
          ),
        ),
        where: (s) => s.activeSafeToSpend!.periodSpent == 6300,
      );
      // (30,000 − 6,300 + 400 today) ÷ 17
      expect(s2.activeSafeToSpend!.dailySafeToSpend, closeTo(24100 / 17, 1e-9));
      expect(other(s2).safeToSpend, b1);

      // 3. Moving B's ₹2,000 (11 Oct) to A moves its effect with it.
      final moved = (await app.expenseRepository.getExpenseById(
        'b-oct11',
      ))!.copyWith(budgetId: 'a');
      final s3 = await after(
        () => run(ExpenseUpdate(moved)),
        where: (s) => s.activeSafeToSpend!.periodSpent == 8300,
      );
      // A: (30,000 − 8,300 + 400) ÷ 17. B: (15,000 − 1,100 + 1,100) ÷ 27.
      expect(s3.activeSafeToSpend!.dailySafeToSpend, closeTo(22100 / 17, 1e-9));
      expect(other(s3).safeToSpend!.periodSpent, 1100);
      expect(other(s3).dailyLimit, closeTo(15000 / 27, 1e-9));

      // 4. Deleting A's ₹400 from today: today's amount holds (it was added
      //    back), what is left today grows by the same ₹400.
      final s4 = await after(
        () => run(const ExpenseDelete('a-oct15')),
        where: (s) => s.activeSafeToSpend!.todaySpent == 0,
      );
      final a4 = s4.activeSafeToSpend!;
      expect(a4.periodSpent, 7900);
      expect(a4.dailySafeToSpend, closeTo(22100 / 17, 1e-9));
      expect(a4.remainingToday, closeTo(22100 / 17, 1e-9));
      expect(other(s4).safeToSpend, other(s3).safeToSpend);
    });
  });
}
