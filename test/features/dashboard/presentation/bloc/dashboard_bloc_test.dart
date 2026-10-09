import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_summary_usecase.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/repository/bill_repository.dart';
import 'package:monivo/features/dashboard/domain/entities/committed_spending.dart';
import 'package:monivo/features/dashboard/domain/entities/recent_expense_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/smart_insight_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_entity.dart';
import 'package:monivo/features/dashboard/domain/repository/dashboard_repository.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_recent_expenses_usecase.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_smart_insights_usecase.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockGetSmartInsightsUseCase implements GetSmartInsightsUseCase {
  @override
  List<SmartInsight> call(
    BudgetSummaryEntity summary, {
    SpendingTargetEntity? spendingTarget,
    List<dynamic>? budgetDailyLimits,
    SafeToSpendEntity? safeToSpend,
  }) => const [];
}

class MockGetBudgetSummaryUseCase implements GetBudgetSummaryUseCase {
  final BudgetResult<BudgetSummaryEntity>? resultToReturn;

  MockGetBudgetSummaryUseCase({this.resultToReturn});

  @override
  final BudgetRepository repository = MockBudgetRepository();

  @override
  final BudgetCalculationService calculationService =
      BudgetCalculationService();

  @override
  Future<BudgetResult<BudgetSummaryEntity>> call({
    required String budgetId,
    DateTime? referenceDate,
  }) async {
    if (resultToReturn != null) {
      return resultToReturn!;
    }
    throw UnimplementedError();
  }
}

class MockBudgetRepository implements BudgetRepository {
  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();

  @override
  Future<BudgetEntity?> getActiveBudget() async => null;

  @override
  Future<String?> getActiveBudgetId() async => 'active-budget';

  @override
  Future<void> setActiveBudgetId(String budgetId) async {}

  @override
  Future<BudgetEntity?> getBudgetById(String id) async => null;

  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async => [];

  @override
  Future<BudgetEntity> createBudget(BudgetEntity budget) async => budget;

  @override
  Future<BudgetEntity> updateBudget(BudgetEntity budget) async => budget;

  @override
  Future<void> deleteBudget(String id) async {}

  @override
  Future<BudgetEntity> setBudgetArchived(
    String id, {
    required bool archived,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    return MonthlyStatisticsEntity.empty;
  }

  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 0;

  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 1;

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    return const BudgetError(
      BudgetFailure(type: BudgetErrorType.notFound, message: 'No budget found'),
    );
  }

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}

  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => 0.0;
}

class MockGetSpendingTargetsUseCase implements GetSpendingTargetsUseCase {
  @override
  final BudgetRepository repository = MockBudgetRepository();
  @override
  final BudgetCalculationService calculationService =
      BudgetCalculationService();

  @override
  Future<SpendingTargetResult> call({DateTime? referenceDate}) async {
    return const SpendingTargetNoBudget();
  }

  @override
  Future<PerBudgetSpendingTargetResult> callPerBudget({
    DateTime? referenceDate,
  }) async {
    return const PerBudgetSpendingTargetNoBudget();
  }
}

class MockGetSafeToSpendUseCase implements GetSafeToSpendUseCase {
  final BudgetResult<SafeToSpendEntity>? resultToReturn;
  final List<String> requestedBudgetIds = [];
  final List<DateTime?> requestedDates = [];

  MockGetSafeToSpendUseCase({this.resultToReturn});

  @override
  Future<BudgetResult<SafeToSpendEntity>> call({
    required String budgetId,
    DateTime? referenceDate,
  }) async {
    requestedBudgetIds.add(budgetId);
    requestedDates.add(referenceDate);
    return resultToReturn ??
        const BudgetError(
          BudgetFailure(
            type: BudgetErrorType.notFound,
            message: 'Budget not found',
          ),
        );
  }

  @override
  Future<Map<String, SafeToSpendEntity>> callForBudgets(
    List<BudgetEntity> budgets, {
    required DateTime referenceDate,
    List<BudgetEntity>? allBudgets,
  }) async => const {};
}

class MockGetRecentExpensesUseCase implements GetRecentExpensesUseCase {
  final List<RecentExpenseEntity>? expensesToReturn;

  MockGetRecentExpensesUseCase({this.expensesToReturn});

  @override
  final DashboardRepository repository = MockDashboardRepository();

  @override
  Future<List<RecentExpenseEntity>> call({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  }) async {
    if (expensesToReturn != null) {
      return expensesToReturn!;
    }
    return [];
  }
}

class ThrowingRecentExpensesUseCase extends MockGetRecentExpensesUseCase {
  final Object error;

  ThrowingRecentExpensesUseCase(this.error);

  @override
  Future<List<RecentExpenseEntity>> call({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  }) async => throw error;
}

class MockDashboardRepository implements DashboardRepository {
  @override
  Future<List<RecentExpenseEntity>> getRecentExpenses({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  }) async {
    return [];
  }

  @override
  Future<Map<String, CommittedSpending>> getCommittedSpending({
    required List<BudgetEntity> budgets,
    required DateTime today,
  }) async => {for (final b in budgets) b.id: CommittedSpending.zero};

  @override
  Future<Map<DateTime, double>> getDailyDiscretionarySpending({
    required String budgetId,
    required DateTime start,
    required DateTime end,
  }) async => const {};
}

class FakeBillRepository implements BillRepository {
  @override
  Future<void> createBill(BillEntity bill) async {}
  @override
  Future<void> updateBill(BillEntity bill) async {}
  @override
  Future<void> deleteBill(String id) async {}
  @override
  Future<BillEntity?> getBillById(String id) async => null;
  @override
  Future<List<BillEntity>> getBills() async => [];
  @override
  Future<void> createBillPayment(BillPaymentRecord payment) async {}
  @override
  Future<List<BillPaymentRecord>> getBillPayments(String billId) async => [];
  @override
  Future<void> deleteBillPayment(String paymentId) async {}
  @override
  Future<List<BillEntity>> getUpcomingBills({
    DateTime? from,
    int limit = 3,
  }) async {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming =
        (await getBills())
            .where((b) => !b.isPaid && !b.dueDate.isBefore(today))
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming.take(limit).toList();
  }

  @override
  Future<double> getUpcomingBillsTotal({int withinDays = 30}) async => 0;
  @override
  Future<double> getMonthlyRecurringBillsTotal() async => 0;

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}

final tBudgetSummary = BudgetSummaryEntity(
  monthlyAmount: 30000,
  remainingBudget: 21500,
  totalSpent: 8500,
  todaySpending: 860,
  remainingDays: 12,
  daysPassed: 18,
  dailySafeSpending: 1240,
  budgetUtilization: 0.28,
  spendingPercentage: 28.0,
  remainingPercentage: 72.0,
  averageDailySpending: 472,
  expectedPeriodEndSpending: 18500,
  expectedSavings: 11500,
  expectedOverspending: 0,
  todayOverspending: 0,
  status: BudgetStatus.underBudget,
  currency: '₹',
  startDate: DateTime(2026, 8, 1),
  endDate: DateTime(2026, 8, 31),
);

final tRecentExpenses = [
  RecentExpenseEntity(
    id: '1',
    amount: 100,
    categoryId: 'cat1',
    categoryName: 'Food',
    categoryIcon: 'restaurant',
    categoryColorHex: '#FF6B6B',
    date: DateTime(2026, 8, 4),
    createdAt: DateTime(2026, 8, 4),
  ),
];

void main() {
  late DashboardBloc dashboardBloc;
  late MockGetBudgetSummaryUseCase mockGetBudgetSummaryUseCase;
  late MockGetRecentExpensesUseCase mockGetRecentExpensesUseCase;

  setUp(() {
    mockGetBudgetSummaryUseCase = MockGetBudgetSummaryUseCase(
      resultToReturn: BudgetSuccess(tBudgetSummary),
    );
    mockGetRecentExpensesUseCase = MockGetRecentExpensesUseCase(
      expensesToReturn: tRecentExpenses,
    );
    dashboardBloc = DashboardBloc(
      getBudgetSummaryUseCase: mockGetBudgetSummaryUseCase,
      getRecentExpensesUseCase: mockGetRecentExpensesUseCase,
      getSmartInsightsUseCase: MockGetSmartInsightsUseCase(),
      getSpendingTargetsUseCase: MockGetSpendingTargetsUseCase(),
      getSafeToSpendUseCase: MockGetSafeToSpendUseCase(),
      budgetRepository: MockBudgetRepository(),
      billRepository: FakeBillRepository(),
    );
  });

  tearDown(() {
    dashboardBloc.close();
  });

  test('initial state is DashboardInitial', () {
    expect(dashboardBloc.state, const DashboardInitial());
  });

  test(
    'emits [DashboardLoading, DashboardLoaded] when data loads successfully',
    () async {
      final bloc = DashboardBloc(
        getBudgetSummaryUseCase: MockGetBudgetSummaryUseCase(
          resultToReturn: BudgetSuccess(tBudgetSummary),
        ),
        getRecentExpensesUseCase: MockGetRecentExpensesUseCase(
          expensesToReturn: tRecentExpenses,
        ),
        getSmartInsightsUseCase: MockGetSmartInsightsUseCase(),
        getSpendingTargetsUseCase: MockGetSpendingTargetsUseCase(),
        getSafeToSpendUseCase: MockGetSafeToSpendUseCase(),
        budgetRepository: MockBudgetRepository(),
        billRepository: FakeBillRepository(),
      );

      final expected = [
        const DashboardLoading(),
        DashboardLoaded(
          budgetSummary: tBudgetSummary,
          recentExpenses: tRecentExpenses,
          insights: const [],
          activeBudgetId: 'active-budget',
        ),
      ];

      final future = expectLater(bloc.stream, emitsInOrder(expected));

      bloc.add(const DashboardLoadData());

      await future;
      await bloc.close();
    },
  );

  test(
    'emits [DashboardLoading, DashboardEmpty] when no budget is found',
    () async {
      final bloc = DashboardBloc(
        getBudgetSummaryUseCase: MockGetBudgetSummaryUseCase(
          resultToReturn: const BudgetError(
            BudgetFailure(
              type: BudgetErrorType.notFound,
              message: 'No budget found',
            ),
          ),
        ),
        getRecentExpensesUseCase: MockGetRecentExpensesUseCase(),
        getSmartInsightsUseCase: MockGetSmartInsightsUseCase(),
        getSpendingTargetsUseCase: MockGetSpendingTargetsUseCase(),
        getSafeToSpendUseCase: MockGetSafeToSpendUseCase(),
        budgetRepository: MockBudgetRepository(),
        billRepository: FakeBillRepository(),
      );

      final expected = const [DashboardLoading(), DashboardEmpty()];

      expectLater(bloc.stream, emitsInOrder(expected));

      bloc.add(const DashboardLoadData());

      await bloc.close();
    },
  );

  test(
    'emits [DashboardLoading, DashboardError] with the real message when the '
    'storage layer throws',
    () async {
      // A migration gap (schema v5 → categories without is_archived) made
      // the recent-expenses query throw. The dashboard used to swallow the
      // exception as an unhandled bloc error and stay on its skeleton.
      final bloc = DashboardBloc(
        getBudgetSummaryUseCase: MockGetBudgetSummaryUseCase(
          resultToReturn: BudgetSuccess(tBudgetSummary),
        ),
        getRecentExpensesUseCase: ThrowingRecentExpensesUseCase(
          StateError('Null check operator used on a null value'),
        ),
        getSmartInsightsUseCase: MockGetSmartInsightsUseCase(),
        getSpendingTargetsUseCase: MockGetSpendingTargetsUseCase(),
        getSafeToSpendUseCase: MockGetSafeToSpendUseCase(),
        budgetRepository: MockBudgetRepository(),
        billRepository: FakeBillRepository(),
      );

      final future = expectLater(
        bloc.stream,
        emitsInOrder([
          const DashboardLoading(),
          isA<DashboardError>().having(
            (s) => s.message,
            'message',
            contains('Null check operator used on a null value'),
          ),
        ]),
      );

      bloc.add(const DashboardLoadData());

      await future;
      await bloc.close();
    },
  );

  test('emits [DashboardLoading, DashboardError] on other failures', () async {
    final bloc = DashboardBloc(
      getBudgetSummaryUseCase: MockGetBudgetSummaryUseCase(
        resultToReturn: const BudgetError(
          BudgetFailure(
            type: BudgetErrorType.invalidBudget,
            message: 'Budget amount must be greater than zero',
          ),
        ),
      ),
      getRecentExpensesUseCase: MockGetRecentExpensesUseCase(),
      getSmartInsightsUseCase: MockGetSmartInsightsUseCase(),
      getSpendingTargetsUseCase: MockGetSpendingTargetsUseCase(),
      getSafeToSpendUseCase: MockGetSafeToSpendUseCase(),
      budgetRepository: MockBudgetRepository(),
      billRepository: FakeBillRepository(),
    );

    final future = expectLater(
      bloc.stream,
      emitsInOrder(const [
        DashboardLoading(),
        DashboardError(message: 'Budget amount must be greater than zero'),
      ]),
    );

    bloc.add(const DashboardLoadData());

    await future;
    await bloc.close();
  });

  group('active budget not running today (invalidDate)', () {
    // The summary has no daily figure outside the period, so the bloc asks
    // the safe-to-spend engine for the not-started / ended result instead
    // of showing an error.
    final today = DateTime(2026, 8, 20);
    final notStarted = SafeToSpendCalculator(BudgetCalculationService())
        .calculate(
          SafeToSpendInput(
            budgetId: 'active-budget',
            budgetName: 'September',
            currency: 'INR',
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 30),
            today: today,
            budgetAmount: 30000,
            periodSpent: 0,
            todaySpent: 0,
            commitments: const [],
          ),
        );
    const invalidDate = BudgetError<BudgetSummaryEntity>(
      BudgetFailure(
        type: BudgetErrorType.invalidDate,
        message: 'Reference date does not match budget period',
      ),
    );

    test('emits [DashboardLoading, DashboardNotRunning] with the engine '
        'result for the same day', () async {
      final safeToSpend = MockGetSafeToSpendUseCase(
        resultToReturn: BudgetSuccess(notStarted),
      );
      final bloc = DashboardBloc(
        getBudgetSummaryUseCase: MockGetBudgetSummaryUseCase(
          resultToReturn: invalidDate,
        ),
        getRecentExpensesUseCase: MockGetRecentExpensesUseCase(
          expensesToReturn: tRecentExpenses,
        ),
        getSmartInsightsUseCase: MockGetSmartInsightsUseCase(),
        getSpendingTargetsUseCase: MockGetSpendingTargetsUseCase(),
        getSafeToSpendUseCase: safeToSpend,
        budgetRepository: MockBudgetRepository(),
        billRepository: FakeBillRepository(),
        clock: () => DateTime(2026, 8, 20, 18, 45),
      );

      final future = expectLater(
        bloc.stream,
        emitsInOrder([
          const DashboardLoading(),
          DashboardNotRunning(
            activeBudgetId: 'active-budget',
            safeToSpend: notStarted,
            recentExpenses: tRecentExpenses,
          ),
        ]),
      );

      bloc.add(const DashboardLoadData());

      await future;
      expect(notStarted.status, SafeToSpendStatus.notStarted);
      expect(safeToSpend.requestedBudgetIds, ['active-budget']);
      expect(safeToSpend.requestedDates, [today]);
      await bloc.close();
    });

    test('emits DashboardEmpty when the budget is gone', () async {
      final bloc = DashboardBloc(
        getBudgetSummaryUseCase: MockGetBudgetSummaryUseCase(
          resultToReturn: invalidDate,
        ),
        getRecentExpensesUseCase: MockGetRecentExpensesUseCase(),
        getSmartInsightsUseCase: MockGetSmartInsightsUseCase(),
        getSpendingTargetsUseCase: MockGetSpendingTargetsUseCase(),
        getSafeToSpendUseCase: MockGetSafeToSpendUseCase(),
        budgetRepository: MockBudgetRepository(),
        billRepository: FakeBillRepository(),
        clock: () => today,
      );

      final future = expectLater(
        bloc.stream,
        emitsInOrder(const [DashboardLoading(), DashboardEmpty()]),
      );

      bloc.add(const DashboardLoadData());

      await future;
      await bloc.close();
    });
  });

  test(
    'emits [DashboardLoading, DashboardLoaded] with empty expenses',
    () async {
      final bloc = DashboardBloc(
        getBudgetSummaryUseCase: MockGetBudgetSummaryUseCase(
          resultToReturn: BudgetSuccess(tBudgetSummary),
        ),
        getRecentExpensesUseCase: MockGetRecentExpensesUseCase(
          expensesToReturn: const [],
        ),
        getSmartInsightsUseCase: MockGetSmartInsightsUseCase(),
        getSpendingTargetsUseCase: MockGetSpendingTargetsUseCase(),
        getSafeToSpendUseCase: MockGetSafeToSpendUseCase(),
        budgetRepository: MockBudgetRepository(),
        billRepository: FakeBillRepository(),
      );

      final expected = [
        const DashboardLoading(),
        DashboardLoaded(
          budgetSummary: tBudgetSummary,
          recentExpenses: const [],
          insights: const [],
          activeBudgetId: 'active-budget',
        ),
      ];

      final future = expectLater(bloc.stream, emitsInOrder(expected));

      bloc.add(const DashboardLoadData());

      await future;
      await bloc.close();
    },
  );
}
