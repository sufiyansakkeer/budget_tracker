import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/repository/bill_repository.dart';
import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/committed_spending.dart';
import 'package:monivo/features/dashboard/domain/entities/recent_expense_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_status.dart';
import 'package:monivo/features/dashboard/domain/repository/dashboard_repository.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart';

/// In-memory bills for safe-to-spend tests. Also enough for
/// MarkBillPaidUseCase (get, update, payment, transaction).
class SafeSpendFakeBillRepository implements BillRepository {
  final Map<String, BillEntity> store = {};
  final List<BillPaymentRecord> payments = [];
  bool throwOnRead = false;
  int getBillsCalls = 0;

  SafeSpendFakeBillRepository([List<BillEntity> bills = const []]) {
    for (final b in bills) {
      store[b.id] = b;
    }
  }

  @override
  Future<void> createBill(BillEntity bill) async => store[bill.id] = bill;

  @override
  Future<void> updateBill(BillEntity bill) async => store[bill.id] = bill;

  @override
  Future<void> deleteBill(String id) async => store.remove(id);

  @override
  Future<BillEntity?> getBillById(String id) async => store[id];

  @override
  Future<List<BillEntity>> getBills() async {
    getBillsCalls++;
    if (throwOnRead) throw Exception('bills unavailable');
    return store.values.toList();
  }

  @override
  Future<void> createBillPayment(BillPaymentRecord payment) async =>
      payments.add(payment);

  @override
  Future<List<BillPaymentRecord>> getBillPayments(String billId) async =>
      payments.where((p) => p.billId == billId).toList();

  @override
  Future<void> deleteBillPayment(String paymentId) async =>
      payments.removeWhere((p) => p.id == paymentId);

  @override
  Future<List<BillEntity>> getUpcomingBills({
    DateTime? from,
    int limit = 3,
  }) async => const [];

  @override
  Future<double> getUpcomingBillsTotal({int withinDays = 30}) async => 0;

  @override
  Future<double> getMonthlyRecurringBillsTotal() async => 0;

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}

/// Committed bill payments per budget id; missing ids are zero.
class SafeSpendFakeDashboardRepository implements DashboardRepository {
  final Map<String, CommittedSpending> committed;
  int committedCalls = 0;

  SafeSpendFakeDashboardRepository([Map<String, CommittedSpending>? committed])
    : committed = committed ?? {};

  @override
  Future<List<RecentExpenseEntity>> getRecentExpenses({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  }) async => const [];

  @override
  Future<Map<String, CommittedSpending>> getCommittedSpending({
    required List<BudgetEntity> budgets,
    required DateTime today,
  }) async {
    committedCalls++;
    return {
      for (final b in budgets) b.id: committed[b.id] ?? CommittedSpending.zero,
    };
  }

  @override
  Future<Map<DateTime, double>> getDailyDiscretionarySpending({
    required String budgetId,
    required DateTime start,
    required DateTime end,
  }) async => const {};
}

/// A real [GetSafeToSpendUseCase] over [budgetRepository] with no bills and
/// no committed payments unless given.
GetSafeToSpendUseCase fakeSafeToSpendUseCase(
  BudgetRepository budgetRepository, {
  BillRepository? billRepository,
  DashboardRepository? dashboardRepository,
  DateTime Function()? clock,
}) {
  return GetSafeToSpendUseCase(
    budgetRepository: budgetRepository,
    billRepository: billRepository ?? SafeSpendFakeBillRepository(),
    dashboardRepository:
        dashboardRepository ?? SafeSpendFakeDashboardRepository(),
    calculator: SafeToSpendCalculator(BudgetCalculationService()),
    clock: clock,
  );
}

/// A daily-limit entry carrying [entity], with the engine-derived fields
/// filled the way `GetSpendingTargetsUseCase.callPerBudget` fills them (the
/// legacy weekly and ratio fields are placeholders).
BudgetDailyLimitEntity budgetDailyLimitFor(
  SafeToSpendEntity entity, {
  String? name,
}) => BudgetDailyLimitEntity(
  budgetId: entity.budgetId,
  budgetName: name ?? entity.budgetName,
  dailyLimit: entity.dailySafeToSpend,
  spentToday: entity.todayDiscretionary,
  remainingToday: entity.remainingToday,
  exceededToday: entity.overToday,
  progress: 0,
  isOverLimit: entity.overToday > 0,
  status: SpendingTargetStatus.onTrack,
  budgetStatus: BudgetStatus.underBudget,
  budgetUtilization: 0,
  monthlyAmount: entity.budgetAmount,
  totalSpent: entity.periodSpent,
  remainingBudget: entity.availableBalance,
  remainingDays: entity.remainingDays,
  weeklyTarget: 0,
  weeklySpent: 0,
  weeklyRemaining: 0,
  weeklyExceeded: 0,
  weeklyProgress: 0,
  weeklyStatus: SpendingTargetStatus.onTrack,
  currency: entity.currency,
  startDate: entity.startDate,
  endDate: entity.endDate,
  safeToSpend: entity,
);
