import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/entities/bill_failure.dart';
import 'package:monivo/features/bills/domain/usecases/link_bills_to_budget_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_unpaid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/pay_bill_usecase.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/usecases/reset_budget_usecase.dart';

import 'app_harness.dart';

/// Bills and Today's Safe Spending end to end: linking a bill sets it aside,
/// paying it records the expense without lowering today's amount or
/// counting it twice, undoing the payment restores it, and starting a new
/// period carries the bills over. Real repositories, in-memory database,
/// fixed clock.
void main() {
  late AppHarness app;

  /// 10 Aug 2026, 10:00. Aug 10–31 is 22 days including today.
  var now = DateTime(2026, 8, 10, 10);
  DateTime clock() => now;

  setUp(() async {
    now = DateTime(2026, 8, 10, 10);
    app = await AppHarness.create();
  });
  tearDown(() => app.dispose());

  PayBillUseCase payBill() => PayBillUseCase(
    billRepository: app.billRepository,
    budgetRepository: app.budgetRepository,
    expenseRepository: app.expenseRepository,
    clock: clock,
  );

  Future<SafeToSpendEntity> safeToSpend(String budgetId) async {
    final result = await app.getSafeToSpend(
      budgetId: budgetId,
      referenceDate: now,
    );
    return (result as BudgetSuccess<SafeToSpendEntity>).data;
  }

  Future<BudgetEntity> august() => app.addBudget(
    id: 'aug',
    name: 'August',
    amount: 22000,
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 31),
  );

  Future<void> addBill({
    String id = 'rent',
    double amount = 2200,
    DateTime? dueDate,
    bool recurring = false,
    String? budgetId,
  }) => app.billRepository.createBill(
    BillEntity(
      id: id,
      title: 'Rent',
      amount: amount,
      currency: 'INR',
      category: BillCategory.rent,
      dueDate: dueDate ?? DateTime(2026, 8, 20),
      isRecurring: recurring,
      recurrenceType: recurring ? RecurrenceType.monthly : RecurrenceType.none,
      budgetId: budgetId,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    ),
  );

  test('link → today drops; pay with expense → today holds and nothing is '
      'counted twice; mark unpaid → restored', () async {
    await august();
    await addBill();

    final unlinked = await safeToSpend('aug');
    expect(unlinked.dailySafeToSpend, closeTo(1000, 1e-9));
    expect(unlinked.unlinked.count, 1, reason: 'disclosed, not deducted');

    // Link the bill: 2200 is set aside, today's amount drops by 2200/22.
    final link = LinkBillsToBudgetUseCase(
      billRepository: app.billRepository,
      budgetRepository: app.budgetRepository,
    );
    await link(budgetId: 'aug', billIds: ['rent']);
    final linked = await safeToSpend('aug');
    expect(linked.upcomingCommitments, 2200);
    expect(linked.dailySafeToSpend, closeTo(900, 1e-9));
    expect(linked.freeToSpend, 19800);

    // Pay it with an expense the same day.
    final outcome = await payBill()('rent');
    expect(outcome, isA<BillSuccess<BillPaymentOutcome>>());
    final paid = await safeToSpend('aug');
    expect(paid.availableBalance, 19800, reason: 'the expense is spent');
    expect(paid.upcomingCommitments, 0, reason: 'no longer upcoming');
    expect(paid.freeToSpend, 19800, reason: 'not deducted twice');
    expect(paid.dailySafeToSpend, closeTo(900, 1e-9), reason: 'holds today');
    expect(paid.committedSpentToday, 2200);
    expect(paid.todayDiscretionary, 0);
    expect(paid.remainingToday, closeTo(900, 1e-9));
    expect(paid.status, SafeToSpendStatus.onTrack);

    // The dashboard shows the same figure.
    final dashboard = app.dashboardBloc(clock: clock);
    addTearDown(dashboard.close);
    dashboard.add(const DashboardLoadData());
    final state =
        await dashboard.stream.firstWhere((s) => s is DashboardLoaded)
            as DashboardLoaded;
    expect(state.activeBudgetLimit!.dailyLimit, closeTo(900, 1e-9));
    expect(state.activeBudgetLimit!.spentToday, 0);
    expect(state.activeSafeToSpend, paid);

    // Tomorrow the payment is simply spent money: 19800 over 21 days.
    now = DateTime(2026, 8, 11, 8);
    expect(
      (await safeToSpend('aug')).dailySafeToSpend,
      closeTo(19800 / 21, 1e-9),
    );

    // Undo (back on the payment day): the expense goes, the bill is set
    // aside again, and the figures match the linked-but-unpaid ones.
    now = DateTime(2026, 8, 10, 18);
    final unpaid = await MarkBillUnpaidUseCase(
      repository: app.billRepository,
      expenseRepository: app.expenseRepository,
    )('rent');
    expect(unpaid, isA<BillSuccess<BillEntity>>());
    final restored = await safeToSpend('aug');
    expect(restored.availableBalance, 22000);
    expect(restored.upcomingCommitments, 2200);
    expect(restored.dailySafeToSpend, closeTo(900, 1e-9));
    expect(restored.committedSpentToday, 0);
    expect(await app.storedRemaining('aug'), 22000);
    expect(await app.expenseRepository.getExpenses(budgetId: 'aug'), isEmpty);
  });

  test('paying an unlinked bill is plain spending today', () async {
    await august();
    await addBill();

    await payBill()('rent');
    final entity = await safeToSpend('aug');

    expect(entity.committedSpentToday, 0);
    expect(entity.todayDiscretionary, 2200);
    expect(
      entity.dailySafeToSpend,
      closeTo(1000, 1e-9),
      reason: "today's amount is fixed for the day",
    );
    expect(entity.overToday, closeTo(1200, 1e-9));
    expect(entity.status, SafeToSpendStatus.overDailyAllowance);
  });

  test('a recurring linked bill paid today moves to its next occurrence and '
      'today holds', () async {
    await august();
    await addBill(
      dueDate: DateTime(2026, 8, 12),
      recurring: true,
      budgetId: 'aug',
    );
    expect((await safeToSpend('aug')).dailySafeToSpend, closeTo(900, 1e-9));

    await payBill()('rent');
    final entity = await safeToSpend('aug');

    expect(
      (await app.billRepository.getBillById('rent'))!.dueDate,
      DateTime(2026, 9, 12),
    );
    expect(entity.upcomingCommitments, 0, reason: 'Sep 12 is after August');
    expect(entity.dailySafeToSpend, closeTo(900, 1e-9));
  });

  test('starting a new period re-links unpaid bills and carries the '
      'kept-aside and savings amounts', () async {
    await app.addBudget(
      id: 'aug',
      name: 'August',
      amount: 31000,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
    );
    final aug = (await app.budgetRepository.getBudgetById('aug'))!;
    await app.budgetRepository.updateBudget(
      aug.copyWith(reservedAmount: 1000, savingsTarget: 3000),
    );
    await addBill(
      amount: 12000,
      dueDate: DateTime(2026, 9, 5),
      recurring: true,
      budgetId: 'aug',
    );

    now = DateTime(2026, 9, 1, 9);
    final reset = ResetBudgetUseCase(
      repository: app.budgetRepository,
      billRepository: app.billRepository,
      clock: clock,
    );
    final newId =
        ((await reset.resetCurrentMonth()) as SettingsSuccess<String>).data;

    expect((await app.billRepository.getBillById('rent'))!.budgetId, newId);
    final entity = await safeToSpend(newId);
    expect(entity.startDate, DateTime(2026, 9, 1));
    expect(entity.upcomingCommitments, 12000);
    expect(entity.reservedAmount, 1000);
    expect(entity.savingsTarget, 3000);
    expect(entity.freeToSpend, 31000 - 12000 - 1000 - 3000);
    expect(entity.unlinked.count, 0);
  });
}
