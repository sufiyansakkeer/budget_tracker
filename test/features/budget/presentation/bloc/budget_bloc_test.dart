import 'package:bloc_test/bloc_test.dart';
import 'package:budget_tracker/core/domain/entities/budget_entity.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_analytics_entity.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_error.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:budget_tracker/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:budget_tracker/features/budget/domain/repository/budget_repository.dart';
import 'package:budget_tracker/features/budget/domain/services/budget_calculation_service.dart';
import 'package:budget_tracker/features/budget/domain/usecases/get_budget_analytics_usecase.dart';
import 'package:budget_tracker/features/budget/domain/usecases/get_budget_summary_usecase.dart';
import 'package:budget_tracker/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_tracker/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_tracker/features/budget/presentation/bloc/budget_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBudgetRepository implements BudgetRepository {
  BudgetEntity? budget;
  MonthlyStatisticsEntity statistics = MonthlyStatisticsEntity.empty;

  @override
  Future<BudgetEntity?> getCurrentBudget() async => budget;

  @override
  Future<MonthlyStatisticsEntity> getMonthlyStatistics({
    required int month,
    required int year,
    DateTime? referenceDate,
  }) async => statistics;

  @override
  Future<double> getTodaySpending({DateTime? referenceDate}) async =>
      statistics.todaySpending;

  @override
  Future<int> getRemainingDays({DateTime? referenceDate}) async => 22;

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext({
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
        monthlyAmount: 30000,
        remainingAmount: 30000,
        currency: 'INR',
        month: 8,
        year: 2026,
        createdAt: DateTime(2026, 8, 1),
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
    seed: () => const BudgetState(status: BudgetBlocStatus.loaded),
    act: (bloc) => bloc.add(const BudgetRecalculateEvent()),
    expect: () => [
      isA<BudgetState>().having(
        (s) => s.status,
        'status',
        BudgetBlocStatus.loaded,
      ),
    ],
  );
}
