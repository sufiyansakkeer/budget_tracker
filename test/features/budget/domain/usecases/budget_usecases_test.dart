import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/usecases/calculate_daily_allowance_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_analytics_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_status_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_summary_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/get_projected_overspending_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/get_projected_savings_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBudgetRepository implements BudgetRepository {
  BudgetEntity? budget;
  MonthlyStatisticsEntity statistics = MonthlyStatisticsEntity.empty;
  DateTime referenceDate = DateTime(2026, 8, 10);

  @override
  Future<BudgetEntity?> getActiveBudget() async => budget;

  @override
  Future<String?> getActiveBudgetId() async => budget?.id;

  @override
  Future<void> setActiveBudgetId(String budgetId) async {}

  @override
  Future<BudgetEntity?> getBudgetById(String id) async => budget;

  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async {
    final all = budget == null ? <BudgetEntity>[] : [budget!];
    if (options?.filter == BudgetFilter.archived) {
      return all.where((b) => b.isArchived).toList();
    }
    if (options?.filter == BudgetFilter.active) {
      return all.where((b) => !b.isArchived).toList();
    }
    return all;
  }

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
    final b = budget;
    if (b == null) throw StateError('No budget');
    budget = b.copyWith(isArchived: archived);
    return budget!;
  }

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final b = budget!;
    return BudgetEntity(
      id: 'duplicated',
      name: newName,
      monthlyAmount: b.monthlyAmount,
      remainingAmount: b.monthlyAmount,
      currency: b.currency,
      startDate: startDate ?? b.startDate,
      endDate: endDate ?? b.endDate,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
  }

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => statistics;

  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async => statistics.todaySpending;

  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    if (budget == null) return 1;
    return budget!.daysRemaining(referenceDate ?? this.referenceDate);
  }

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    if (budget == null) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.notFound,
          message: 'No budget found',
        ),
      );
    }

    final date = referenceDate ?? this.referenceDate;
    if (!budget!.isActiveOn(date)) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidDate,
          message: 'Invalid date',
        ),
      );
    }

    return BudgetSuccess(
      BudgetCalculationContext(
        budget: budget!,
        statistics: statistics,
        referenceDate: date,
      ),
    );
  }

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}
}

void main() {
  late FakeBudgetRepository repository;
  late BudgetCalculationService calculationService;

  final tStart = DateTime(2026, 8, 1);
  final tEnd = DateTime(2026, 8, 31);

  final tBudget = BudgetEntity(
    id: 'budget-1',
    name: 'Personal',
    monthlyAmount: 30000,
    remainingAmount: 30000,
    currency: 'INR',
    startDate: tStart,
    endDate: tEnd,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );

  setUp(() {
    repository = FakeBudgetRepository()..budget = tBudget;
    calculationService = BudgetCalculationService();
  });

  group('GetBudgetSummaryUseCase', () {
    test('returns summary when budget exists', () async {
      final useCase = GetBudgetSummaryUseCase(
        repository: repository,
        calculationService: calculationService,
      );

      final result = await useCase(
        budgetId: 'budget-1',
        referenceDate: DateTime(2026, 8, 10),
      );

      expect(result, isA<BudgetSuccess>());
      final summary = (result as BudgetSuccess).data;
      expect(summary.monthlyAmount, 30000);
      expect(summary.currency, 'INR');
    });

    test('returns error when no budget found', () async {
      repository.budget = null;
      final useCase = GetBudgetSummaryUseCase(
        repository: repository,
        calculationService: calculationService,
      );

      final result = await useCase(budgetId: 'budget-1');

      expect(result, isA<BudgetError>());
      expect((result as BudgetError).failure.type, BudgetErrorType.notFound);
    });

    test('returns error for invalid budget amount', () async {
      repository.budget = BudgetEntity(
        id: 'bad',
        name: 'Bad',
        monthlyAmount: 0,
        remainingAmount: 0,
        currency: 'INR',
        startDate: tStart,
        endDate: tEnd,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );

      final useCase = GetBudgetSummaryUseCase(
        repository: repository,
        calculationService: calculationService,
      );

      final result = await useCase(
        budgetId: 'bad',
        referenceDate: DateTime(2026, 8, 10),
      );
      expect(
        (result as BudgetError).failure.type,
        BudgetErrorType.invalidBudget,
      );
    });
  });

  group('CalculateDailyAllowanceUseCase', () {
    test('returns daily allowance for current budget', () async {
      repository.statistics = const MonthlyStatisticsEntity(
        totalSpent: 800,
        expenseCount: 1,
        todaySpending: 800,
      );

      final useCase = CalculateDailyAllowanceUseCase(
        repository: repository,
        calculationService: calculationService,
      );

      final result = await useCase(
        budgetId: 'budget-1',
        referenceDate: DateTime(2026, 8, 10),
      );
      expect(result, isA<BudgetSuccess>());
      // (30000-800)/22 ≈ 1327.27
      expect((result as BudgetSuccess).data, closeTo(1327.27, 0.01));
    });
  });

  group('GetBudgetStatusUseCase', () {
    test('returns underBudget for low spending', () async {
      final useCase = GetBudgetStatusUseCase(
        repository: repository,
        calculationService: calculationService,
      );

      final result = await useCase(
        budgetId: 'budget-1',
        referenceDate: DateTime(2026, 8, 10),
      );
      expect((result as BudgetSuccess).data, BudgetStatus.underBudget);
    });

    test('returns overBudget when spent exceeds monthly amount', () async {
      repository.statistics = const MonthlyStatisticsEntity(
        totalSpent: 35000,
        expenseCount: 5,
        todaySpending: 1000,
      );

      final useCase = GetBudgetStatusUseCase(
        repository: repository,
        calculationService: calculationService,
      );

      final result = await useCase(
        budgetId: 'budget-1',
        referenceDate: DateTime(2026, 8, 10),
      );
      expect((result as BudgetSuccess).data, BudgetStatus.overBudget);
    });
  });

  group('GetProjectedSavingsUseCase', () {
    test('returns savings when spending pace is under budget', () async {
      repository.statistics = const MonthlyStatisticsEntity(
        totalSpent: 9000,
        expenseCount: 3,
        todaySpending: 500,
      );

      final useCase = GetProjectedSavingsUseCase(
        repository: repository,
        calculationService: calculationService,
      );

      final result = await useCase(
        budgetId: 'budget-1',
        referenceDate: DateTime(2026, 8, 10),
      );
      expect(result, isA<BudgetSuccess>());
      expect((result as BudgetSuccess).data, greaterThan(0));
    });
  });

  group('GetProjectedOverspendingUseCase', () {
    test('returns overspending when pace exceeds budget', () async {
      repository.statistics = const MonthlyStatisticsEntity(
        totalSpent: 20000,
        expenseCount: 10,
        todaySpending: 3000,
      );

      final useCase = GetProjectedOverspendingUseCase(
        repository: repository,
        calculationService: calculationService,
      );

      final result = await useCase(
        budgetId: 'budget-1',
        referenceDate: DateTime(2026, 8, 10),
      );
      expect(result, isA<BudgetSuccess>());
      expect((result as BudgetSuccess).data, greaterThan(0));
    });
  });

  group('GetBudgetAnalyticsUseCase', () {
    test('returns analytics with days passed and remaining', () async {
      repository.statistics = const MonthlyStatisticsEntity(
        totalSpent: 5000,
        expenseCount: 2,
        todaySpending: 200,
      );

      final useCase = GetBudgetAnalyticsUseCase(
        repository: repository,
        calculationService: calculationService,
      );

      final result = await useCase(
        budgetId: 'budget-1',
        referenceDate: DateTime(2026, 8, 10),
      );
      expect(result, isA<BudgetSuccess>());
      final analytics = (result as BudgetSuccess).data;
      expect(analytics.daysPassed, 10);
      expect(analytics.daysRemaining, 22);
    });
  });
}
