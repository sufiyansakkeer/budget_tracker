import 'package:budget_tracker/core/domain/entities/budget_entity.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_error.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_filter.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_status.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:budget_tracker/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:budget_tracker/features/budget/domain/repository/budget_repository.dart';
import 'package:budget_tracker/features/budget/domain/services/budget_calculation_service.dart';
import 'package:budget_tracker/features/budget/domain/usecases/get_budget_summary_usecase.dart';
import 'package:budget_tracker/features/dashboard/domain/entities/recent_expense_entity.dart';
import 'package:budget_tracker/features/dashboard/domain/entities/smart_insight_entity.dart';
import 'package:budget_tracker/features/dashboard/domain/repository/dashboard_repository.dart';
import 'package:budget_tracker/features/dashboard/domain/usecases/get_recent_expenses_usecase.dart';
import 'package:budget_tracker/features/dashboard/domain/usecases/get_smart_insights_usecase.dart';
import 'package:budget_tracker/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_tracker/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:budget_tracker/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockGetSmartInsightsUseCase implements GetSmartInsightsUseCase {
  @override
  List<SmartInsight> call(BudgetSummaryEntity summary) => const [];
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

class MockDashboardRepository implements DashboardRepository {
  @override
  Future<List<RecentExpenseEntity>> getRecentExpenses({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  }) async {
    return [];
  }
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
      budgetRepository: MockBudgetRepository(),
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
        budgetRepository: MockBudgetRepository(),
      );

      final expected = [
        const DashboardLoading(),
        DashboardLoaded(
          budgetSummary: tBudgetSummary,
          recentExpenses: tRecentExpenses,
          insights: const [],
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
        budgetRepository: MockBudgetRepository(),
      );

      final expected = const [DashboardLoading(), DashboardEmpty()];

      expectLater(bloc.stream, emitsInOrder(expected));

      bloc.add(const DashboardLoadData());

      await bloc.close();
    },
  );

  test('emits [DashboardLoading, DashboardError] on other failures', () async {
    final bloc = DashboardBloc(
      getBudgetSummaryUseCase: MockGetBudgetSummaryUseCase(
        resultToReturn: const BudgetError(
          BudgetFailure(
            type: BudgetErrorType.invalidDate,
            message: 'Invalid date',
          ),
        ),
      ),
      getRecentExpensesUseCase: MockGetRecentExpensesUseCase(),
      getSmartInsightsUseCase: MockGetSmartInsightsUseCase(),
      budgetRepository: MockBudgetRepository(),
    );

    final expected = const [
      DashboardLoading(),
      DashboardError(message: 'Invalid date'),
    ];

    expectLater(bloc.stream, emitsInOrder(expected));

    bloc.add(const DashboardLoadData());

    await bloc.close();
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
        budgetRepository: MockBudgetRepository(),
      );

      final expected = [
        const DashboardLoading(),
        DashboardLoaded(
          budgetSummary: tBudgetSummary,
          recentExpenses: const [],
          insights: const [],
        ),
      ];

      final future = expectLater(bloc.stream, emitsInOrder(expected));

      bloc.add(const DashboardLoadData());

      await future;
      await bloc.close();
    },
  );
}
