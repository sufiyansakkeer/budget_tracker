import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_reason.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/dashboard/domain/entities/committed_spending.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart';

import '../../../../helpers/safe_to_spend_fakes.dart';
import 'get_spending_targets_usecase_test.dart' show FakeBudgetRepository;

void main() {
  // House fixture: Aug 2026, evaluated on day 10 (22 days left incl. today).
  final today = DateTime(2026, 8, 10);

  late FakeBudgetRepository budgets;
  late SafeSpendFakeBillRepository bills;
  late SafeSpendFakeDashboardRepository dashboard;
  late GetSafeToSpendUseCase useCase;

  setUp(() {
    budgets = FakeBudgetRepository();
    bills = SafeSpendFakeBillRepository();
    dashboard = SafeSpendFakeDashboardRepository();
    useCase = fakeSafeToSpendUseCase(
      budgets,
      billRepository: bills,
      dashboardRepository: dashboard,
      clock: () => DateTime(2026, 8, 10, 14, 30),
    );
  });

  BudgetEntity budget({
    String id = 'aug',
    double amount = 30000,
    DateTime? start,
    DateTime? end,
    String currency = 'INR',
  }) {
    final s = start ?? DateTime(2026, 8, 1);
    return BudgetEntity(
      id: id,
      name: 'Budget $id',
      monthlyAmount: amount,
      remainingAmount: amount,
      currency: currency,
      startDate: s,
      endDate: end ?? DateTime(2026, 8, 31),
      createdAt: s,
      updatedAt: s,
    );
  }

  BillEntity bill({
    String id = 'rent',
    double amount = 2200,
    required DateTime due,
    String? budgetId = 'aug',
    RecurrenceType recurrence = RecurrenceType.none,
  }) {
    return BillEntity(
      id: id,
      title: 'Bill $id',
      amount: amount,
      currency: 'INR',
      category: BillCategory.rent,
      dueDate: due,
      isRecurring: recurrence != RecurrenceType.none,
      recurrenceType: recurrence,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      budgetId: budgetId,
    );
  }

  MonthlyStatisticsEntity stats(double total, {double today = 0}) =>
      MonthlyStatisticsEntity(
        totalSpent: total,
        expenseCount: total > 0 ? 1 : 0,
        todaySpending: today,
      );

  Future<SafeToSpendEntity> evaluate(String budgetId) async {
    final result = await useCase(budgetId: budgetId, referenceDate: today);
    return (result as BudgetSuccess<SafeToSpendEntity>).data;
  }

  group('committed bill payments', () {
    test('paying a set-aside bill today leaves the daily amount unchanged '
        '(no double deduction)', () async {
      budgets.budgets = [budget()];
      bills.store['rent'] = bill(due: DateTime(2026, 8, 20));

      final before = await evaluate('aug');
      // 27800 free ÷ 22 days.
      expect(before.upcomingCommitments, 2200);
      expect(before.dailySafeToSpend, closeTo(27800 / 22, 1e-9));

      // PayBill: one-time bill marked paid, expense with bill_id today.
      bills.store['rent'] = bills.store['rent']!.copyWith(
        isPaid: true,
        paidDate: today,
      );
      budgets.statisticsByBudget = {'aug': stats(2200, today: 2200)};
      dashboard.committed['aug'] = const CommittedSpending(
        periodTotal: 2200,
        todayTotal: 2200,
      );

      final after = await evaluate('aug');
      expect(after.upcomingCommitments, 0);
      expect(after.availableBalance, 27800);
      expect(after.todaySpent, 2200);
      expect(after.todayDiscretionary, 0);
      expect(after.dailySafeToSpend, before.dailySafeToSpend);
      expect(after.remainingToday, before.remainingToday);
      expect(after.rawSpendable, before.rawSpendable);
      expect(after.status, isNot(SafeToSpendStatus.overDailyAllowance));
      expect(after.reasons, contains(const BillPaymentsTodayReason(2200)));
    });

    test('paying a recurring set-aside bill advances it out of the period '
        'and leaves the daily amount unchanged', () async {
      budgets.budgets = [budget()];
      final rent = bill(
        due: DateTime(2026, 8, 20),
        recurrence: RecurrenceType.monthly,
      );
      bills.store['rent'] = rent;
      final before = await evaluate('aug');

      bills.store['rent'] = rent.copyWith(dueDate: rent.nextDueDate);
      budgets.statisticsByBudget = {'aug': stats(2200, today: 2200)};
      dashboard.committed['aug'] = const CommittedSpending(
        periodTotal: 2200,
        todayTotal: 2200,
      );

      final after = await evaluate('aug');
      expect(after.commitments, isEmpty);
      expect(after.dailySafeToSpend, before.dailySafeToSpend);
    });

    test('paying an unlinked bill is plain spending today', () async {
      budgets.budgets = [budget()];
      bills.store['rent'] = bill(due: DateTime(2026, 8, 20), budgetId: null);

      final before = await evaluate('aug');
      expect(before.upcomingCommitments, 0);
      expect(before.unlinked.count, 1);
      expect(before.dailySafeToSpend, closeTo(30000 / 22, 1e-9));

      // Payment recorded without bill_id (nothing was set aside).
      bills.store['rent'] = bills.store['rent']!.copyWith(isPaid: true);
      budgets.statisticsByBudget = {'aug': stats(2200, today: 2200)};

      final after = await evaluate('aug');
      // Fixed for the day, and today's payment counts against it.
      expect(after.dailySafeToSpend, before.dailySafeToSpend);
      expect(after.todayDiscretionary, 2200);
      expect(after.overToday, closeTo(2200 - 30000 / 22, 1e-9));
      expect(after.status, SafeToSpendStatus.overDailyAllowance);
      expect(after.unlinked.isEmpty, isTrue);
    });
  });

  group('budgets are independent', () {
    test(
      'each budget sees only its own bills, spending and payments',
      () async {
        final food = budget(id: 'food', amount: 6000);
        final travel = budget(id: 'travel', amount: 5000);
        budgets.budgets = [food, travel];
        budgets.statisticsByBudget = {
          'food': stats(2000, today: 300),
          'travel': stats(1000),
        };
        bills.store['rent'] = bill(
          due: DateTime(2026, 8, 20),
          budgetId: 'food',
        );
        dashboard.committed['travel'] = const CommittedSpending(
          periodTotal: 400,
          todayTotal: 0,
        );

        final results = await useCase.callForBudgets([
          food,
          travel,
        ], referenceDate: today);

        expect(results.keys, unorderedEquals(['food', 'travel']));
        final f = results['food']!;
        final t = results['travel']!;

        expect(f.periodSpent, 2000);
        expect(f.upcomingCommitments, 2200);
        expect(f.committedSpentInPeriod, 0);
        // (6000 − 2000 − 2200 + 300) ÷ 22
        expect(f.dailySafeToSpend, closeTo(2100 / 22, 1e-9));

        expect(t.periodSpent, 1000);
        expect(t.upcomingCommitments, 0);
        expect(t.committedSpentInPeriod, 400);
        expect(t.todaySpent, 0);
        expect(t.dailySafeToSpend, closeTo(4000 / 22, 1e-9));
      },
    );

    test(
      'one bills read and one committed-spending read for all budgets',
      () async {
        final list = [budget(id: 'a'), budget(id: 'b'), budget(id: 'c')];
        budgets.budgets = list;

        await useCase.callForBudgets(list, referenceDate: today);

        expect(bills.getBillsCalls, 1);
        expect(dashboard.committedCalls, 1);
      },
    );

    test('a budget the engine cannot evaluate is left out; the others keep '
        'their figures (review: one 1e17 budget cleared every hero)', () async {
      final huge = budget(id: 'huge', amount: 1e17);
      final food = budget(id: 'food', amount: 6000);
      budgets.budgets = [huge, food];

      final results = await useCase.callForBudgets([
        huge,
        food,
      ], referenceDate: today);

      expect(results.keys, ['food']);
      expect(results['food']!.dailySafeToSpend, closeTo(6000 / 22, 1e-9));
    });

    test('no budgets → empty map without reading anything', () async {
      final results = await useCase.callForBudgets(
        const [],
        referenceDate: today,
      );
      expect(results, isEmpty);
      expect(bills.getBillsCalls, 0);
      expect(dashboard.committedCalls, 0);
    });

    test(
      'a bill linked to an ended budget is disclosed as not linked',
      () async {
        final july = budget(
          id: 'jul',
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 31),
        );
        final august = budget();
        budgets.budgets = [july, august];
        bills.store['rent'] = bill(
          due: DateTime(2026, 7, 20),
          budgetId: 'jul',
          recurrence: RecurrenceType.monthly,
        );

        final results = await useCase.callForBudgets([
          august,
        ], referenceDate: today);

        final a = results['aug']!;
        expect(a.upcomingCommitments, 0);
        expect(a.unlinked.count, 1);
        expect(a.unlinked.total, 2200);
        expect(a.reasons.whereType<BillsNotLinkedReason>(), hasLength(1));
      },
    );

    test('reserve and savings goal come from the budget', () async {
      budgets.budgets = [
        budget().copyWith(reservedAmount: 1000, savingsTarget: 3000),
      ];
      final s = await evaluate('aug');
      expect(s.reservedAmount, 1000);
      expect(s.savingsTarget, 3000);
      expect(s.dailySafeToSpend, closeTo(26000 / 22, 1e-9));
    });
  });

  group('bills unavailable', () {
    test(
      'a bills read failure reports unavailable instead of failing',
      () async {
        budgets.budgets = [budget()];
        bills.throwOnRead = true;

        final s = await evaluate('aug');

        expect(s.commitmentsAvailable, isFalse);
        expect(s.upcomingCommitments, 0);
        expect(s.commitments, isEmpty);
        expect(s.dailySafeToSpend, closeTo(30000 / 22, 1e-9));
        // Never "On track" on an optimistic figure.
        expect(s.status, SafeToSpendStatus.spendingCarefully);
        expect(s.reasons.first, const BillsUnavailableReason());
      },
    );
  });

  group('phases', () {
    test('a budget that has not started: no daily amount, bills in its '
        'window listed, today\'s spending ignored', () async {
      budgets.budgets = [
        budget(
          id: 'sep',
          start: DateTime(2026, 9, 1),
          end: DateTime(2026, 9, 30),
        ),
      ];
      budgets.statisticsByBudget = {'sep': stats(0, today: 500)};
      bills.store['rent'] = bill(
        due: DateTime(2026, 8, 5),
        budgetId: 'sep',
        recurrence: RecurrenceType.monthly,
      );

      final s = await evaluate('sep');

      expect(s.status, SafeToSpendStatus.notStarted);
      expect(s.dailySafeToSpend, 0);
      expect(s.todaySpent, 0);
      expect(s.daysUntilStart, 22);
      expect(s.commitments.map((o) => o.dueDate), [DateTime(2026, 9, 5)]);
    });

    test('an ended budget: final balance, no daily amount', () async {
      budgets.budgets = [
        budget(
          id: 'jul',
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 31),
        ),
      ];
      budgets.statisticsByBudget = {'jul': stats(31000)};

      final s = await evaluate('jul');

      expect(s.status, SafeToSpendStatus.periodEnded);
      expect(s.dailySafeToSpend, 0);
      expect(s.availableBalance, -1000);
      expect(s.reasons, [const OverBudgetByReason(1000)]);
    });
  });

  group('call', () {
    test('unknown budget → notFound', () async {
      final result = await useCase(budgetId: 'missing', referenceDate: today);
      expect(result, isA<BudgetError<SafeToSpendEntity>>());
      expect(
        (result as BudgetError<SafeToSpendEntity>).failure.type,
        BudgetErrorType.notFound,
      );
    });

    test('a budget the engine cannot evaluate → invalidBudget error, not '
        'a thrown exception', () async {
      budgets.budgets = [budget(amount: 1e17)];
      final result = await useCase(budgetId: 'aug', referenceDate: today);
      expect(result, isA<BudgetError<SafeToSpendEntity>>());
      expect(
        (result as BudgetError<SafeToSpendEntity>).failure.type,
        BudgetErrorType.invalidBudget,
      );
    });

    test(
      'without a reference date uses the injected clock, date only',
      () async {
        budgets.budgets = [budget()];
        final result = await useCase(budgetId: 'aug');
        final s = (result as BudgetSuccess<SafeToSpendEntity>).data;
        expect(s.today, DateTime(2026, 8, 10));
        expect(s.remainingDays, 22);
      },
    );

    test('a reference date late in the day is the same day', () async {
      budgets.budgets = [budget()];
      final result = await useCase(
        budgetId: 'aug',
        referenceDate: DateTime(2026, 8, 31, 23, 59),
      );
      final s = (result as BudgetSuccess<SafeToSpendEntity>).data;
      expect(s.today, DateTime(2026, 8, 31));
      expect(s.remainingDays, 1);
    });
  });
}
