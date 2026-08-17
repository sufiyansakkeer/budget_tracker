import 'package:bloc_test/bloc_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_analytics_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_analytics_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_summary_usecase.dart';
import 'package:monivo/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:monivo/features/budget/presentation/bloc/budget_event.dart';
import 'package:monivo/features/budget/presentation/bloc/budget_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBudgetRepository implements BudgetRepository {
  BudgetEntity? budget;
  String? activeBudgetId;
  MonthlyStatisticsEntity statistics = MonthlyStatisticsEntity.empty;

  @override
  Future<BudgetEntity?> getActiveBudget() async => budget;

  @override
  Future<String?> getActiveBudgetId() async => activeBudgetId ?? budget?.id;

  @override
  Future<void> setActiveBudgetId(String budgetId) async {
    activeBudgetId = budgetId;
  }

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
    return budget!.daysRemaining(referenceDate ?? DateTime(2026, 8, 10));
  }

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    if (budget == null) {
      return const BudgetError(
        BudgetFailure(type: BudgetErrorType.notFound, message: 'No budget'),
      );
    }
    return BudgetSuccess(
      BudgetCalculationContext(
        budget: budget!,
        statistics: statistics,
        referenceDate: referenceDate ?? DateTime(2026, 8, 10),
      ),
    );
  }

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}
}

void main() {
  late FakeBudgetRepository repository;
  late BudgetCalculationService calculationService;
  late GetBudgetSummaryUseCase summaryUseCase;
  late GetBudgetAnalyticsUseCase analyticsUseCase;

  setUp(() {
    repository = FakeBudgetRepository()
      ..budget = BudgetEntity(
        id: '1',
        name: 'Personal',
        monthlyAmount: 30000,
        remainingAmount: 30000,
        currency: 'INR',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
    calculationService = BudgetCalculationService();
    summaryUseCase = GetBudgetSummaryUseCase(
      repository: repository,
      calculationService: calculationService,
    );
    analyticsUseCase = GetBudgetAnalyticsUseCase(
      repository: repository,
      calculationService: calculationService,
    );
  });

  BudgetBloc buildBloc() => BudgetBloc(
    getBudgetSummaryUseCase: summaryUseCase,
    getBudgetAnalyticsUseCase: analyticsUseCase,
    calculationService: calculationService,
    budgetRepository: repository,
  );

  blocTest<BudgetBloc, BudgetState>(
    'emits loading then loaded on BudgetLoadSummaryEvent',
    build: buildBloc,
    act: (bloc) => bloc.add(const BudgetLoadSummaryEvent()),
    expect: () => [
      isA<BudgetState>().having(
        (s) => s.status,
        'status',
        BudgetBlocStatus.loading,
      ),
      isA<BudgetState>()
          .having((s) => s.status, 'status', BudgetBlocStatus.loaded)
          .having((s) => s.summary, 'summary', isA<BudgetSummaryEntity>())
          .having(
            (s) => s.analytics,
            'analytics',
            isA<BudgetAnalyticsEntity>(),
          ),
    ],
  );

  blocTest<BudgetBloc, BudgetState>(
    'emits error when no budget found',
    build: () {
      repository.budget = null;
      return buildBloc();
    },
    skip: 2, // Skip the constructor's auto-load [loading, error] emissions.
    act: (bloc) => bloc.add(const BudgetLoadSummaryEvent()),
    expect: () => [
      isA<BudgetState>().having(
        (s) => s.status,
        'status',
        BudgetBlocStatus.loading,
      ),
      isA<BudgetState>()
          .having((s) => s.status, 'status', BudgetBlocStatus.error)
          .having((s) => s.errorMessage, 'error', isNotNull),
    ],
  );

  blocTest<BudgetBloc, BudgetState>(
    'BudgetRecalculateEvent refreshes without loading state',
    build: buildBloc,
    act: (bloc) => bloc.add(const BudgetRecalculateEvent()),
    expect: () => [
      // Constructor auto-load.
      isA<BudgetState>().having(
        (s) => s.status,
        'status',
        BudgetBlocStatus.loading,
      ),
      isA<BudgetState>()
          .having((s) => s.status, 'status', BudgetBlocStatus.loaded)
          .having((s) => s.summary, 'summary', isNotNull)
          .having((s) => s.analytics, 'analytics', isNotNull),
    ],
  );
}
