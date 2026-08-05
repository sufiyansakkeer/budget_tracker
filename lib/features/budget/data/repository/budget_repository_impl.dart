import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/entities/budget_error.dart';
import '../../domain/entities/monthly_statistics_entity.dart';
import '../../domain/repository/budget_repository.dart';
import '../../domain/services/budget_calculation_service.dart';
import '../datasource/budget_local_datasource.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetLocalDataSource localDataSource;
  final BudgetCalculationService calculationService;

  BudgetRepositoryImpl({
    required this.localDataSource,
    required this.calculationService,
  });

  @override
  Future<BudgetEntity?> getCurrentBudget() {
    final now = DateTime.now();
    return localDataSource.getBudgetForMonth(month: now.month, year: now.year);
  }

  @override
  Future<MonthlyStatisticsEntity> getMonthlyStatistics({
    required int month,
    required int year,
    DateTime? referenceDate,
  }) {
    final date = referenceDate ?? DateTime.now();
    return localDataSource.getMonthlyStatistics(
      month: month,
      year: year,
      referenceDate: date,
    );
  }

  @override
  Future<double> getTodaySpending({DateTime? referenceDate}) async {
    final now = referenceDate ?? DateTime.now();
    final stats = await getMonthlyStatistics(
      month: now.month,
      year: now.year,
      referenceDate: now,
    );
    return stats.todaySpending;
  }

  @override
  Future<int> getRemainingDays({DateTime? referenceDate}) async {
    final budget = await getCurrentBudget();
    if (budget == null) return 1;

    final date = referenceDate ?? DateTime.now();
    try {
      return calculationService.calculateRemainingDays(
        referenceDate: date,
        budgetMonth: budget.month,
        budgetYear: budget.year,
      );
    } on ArgumentError {
      return 1;
    }
  }

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext({
    DateTime? referenceDate,
  }) async {
    final budget = await getCurrentBudget();
    if (budget == null) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.notFound,
          message: 'No budget found for the current month',
        ),
      );
    }

    final date = referenceDate ?? DateTime.now();

    if (date.month != budget.month || date.year != budget.year) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidDate,
          message:
              'Reference date does not match current budget period '
              '(${budget.month}/${budget.year})',
        ),
      );
    }

    final statistics = await getMonthlyStatistics(
      month: budget.month,
      year: budget.year,
      referenceDate: date,
    );

    return BudgetSuccess(
      BudgetCalculationContext(
        budget: budget,
        statistics: statistics,
        referenceDate: date,
      ),
    );
  }
}
