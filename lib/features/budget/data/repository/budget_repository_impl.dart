import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/entities/budget_error.dart';
import '../../domain/entities/budget_filter.dart';
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
  Future<BudgetEntity?> getActiveBudget() async {
    final activeId = await localDataSource.getActiveBudgetId();
    if (activeId == null) return null;
    return localDataSource.getBudgetById(activeId);
  }

  @override
  Future<String?> getActiveBudgetId() {
    return localDataSource.getActiveBudgetId();
  }

  @override
  Future<void> setActiveBudgetId(String budgetId) {
    return localDataSource.setActiveBudgetId(budgetId);
  }

  @override
  Future<BudgetEntity?> getBudgetById(String id) {
    return localDataSource.getBudgetById(id);
  }

  @override
  Future<List<BudgetEntity>> getAllBudgets({BudgetQueryOptions? options}) {
    return localDataSource.getAllBudgets(options: options);
  }

  @override
  Future<BudgetEntity> createBudget(BudgetEntity budget) {
    return localDataSource.createBudget(budget);
  }

  @override
  Future<BudgetEntity> updateBudget(BudgetEntity budget) {
    return localDataSource.updateBudget(budget);
  }

  @override
  Future<void> deleteBudget(String id) {
    return localDataSource.deleteBudget(id);
  }

  @override
  Future<BudgetEntity> setBudgetArchived(String id, {required bool archived}) {
    return localDataSource.setBudgetArchived(id, archived: archived);
  }

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return localDataSource.duplicateBudget(
      id,
      newName: newName,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) {
    final date = referenceDate ?? DateTime.now();
    return localDataSource.getBudgetStatistics(budgetId, referenceDate: date);
  }

  @override
  Future<double> getTodaySpending(String budgetId, {DateTime? referenceDate}) {
    return localDataSource.getTodaySpending(
      budgetId,
      referenceDate: referenceDate,
    );
  }

  @override
  Future<int> getRemainingDays(String budgetId, {DateTime? referenceDate}) {
    return localDataSource.getRemainingDays(
      budgetId,
      referenceDate: referenceDate,
    );
  }

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    final budget = await localDataSource.getBudgetById(budgetId);
    if (budget == null) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.notFound,
          message: 'Budget not found',
        ),
      );
    }

    final date = referenceDate ?? DateTime.now();

    if (date.isBefore(budget.startDate) || date.isAfter(budget.endDate)) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidDate,
          message:
              'Reference date does not match budget period '
              '(${budget.startDate} to ${budget.endDate})',
        ),
      );
    }

    final statistics = await getBudgetStatistics(budgetId, referenceDate: date);

    return BudgetSuccess(
      BudgetCalculationContext(
        budget: budget,
        statistics: statistics,
        referenceDate: date,
      ),
    );
  }
}
