import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_summary_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBudgetRepository implements BudgetRepository {
  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();

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

  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => 0.0;
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
}
