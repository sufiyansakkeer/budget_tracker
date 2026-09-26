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
  Future<T> transaction<T>(Future<T> Function() action) {
    return localDataSource.transaction(action);
  }

  @override
  Future<BudgetEntity?> getActiveBudget() async {
    final activeId = await getActiveBudgetId();
    if (activeId == null) return null;
    return localDataSource.getBudgetById(activeId);
  }

  /// The id of the active budget, guaranteed to reference a stored budget.
  ///
  /// The id lives in preferences while budgets live in the database, so the
  /// two can drift apart: the active budget is deleted, a backup is restored
  /// with different ids, or the app is opened on data written before the
  /// preference existed. A dangling id used to make every scoped screen
  /// (dashboard, history, reports, widget) report "no budget" while the
  /// budgets list showed the rows. When the stored id no longer resolves,
  /// the most recently started non-archived budget (or, failing that, the
  /// most recently started budget) is made active and returned. `null` means
  /// there is genuinely no budget.
  @override
  Future<String?> getActiveBudgetId() async {
    final storedId = await localDataSource.getActiveBudgetId();
    if (storedId != null &&
        await localDataSource.getBudgetById(storedId) != null) {
      return storedId;
    }

    // Both queries are ordered by start date, newest first.
    var candidates = await localDataSource.getAllBudgets(
      options: const BudgetQueryOptions(filter: BudgetFilter.active),
    );
    if (candidates.isEmpty) {
      candidates = await localDataSource.getAllBudgets();
    }
    if (candidates.isEmpty) return null;

    final fallback = candidates.first;
    await localDataSource.setActiveBudgetId(fallback.id);
    return fallback.id;
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
    // The stored remaining amount is a derived value (amount − applicable
    // expenses). Callers may pass an entity whose remainingAmount predates an
    // amount or date-range change, so it is always recomputed from the
    // persisted expenses after the write, inside the same transaction.
    return localDataSource.transaction(() async {
      await localDataSource.updateBudget(budget);
      await updateBudgetRemainingAmount(budget.id);
      final refreshed = await localDataSource.getBudgetById(budget.id);
      return refreshed ?? budget;
    });
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

    // Compared by calendar day, like every other period rule (remaining
    // days, statistics ranges, `isActiveOn`). A budget whose stored dates
    // carry a time of day — onboarding stores the creation instant — would
    // otherwise be "outside its period" for part of its first and last day.
    if (!budget.isActiveOn(date)) {
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

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {
    final budget = await localDataSource.getBudgetById(budgetId);
    if (budget == null) return;

    final statistics = await getBudgetStatistics(budgetId);
    final newRemaining = calculationService.calculateRemainingBudget(
      monthlyAmount: budget.monthlyAmount,
      totalSpent: statistics.totalSpent,
    );

    final updatedBudget = budget.copyWith(remainingAmount: newRemaining);
    await localDataSource.updateBudget(updatedBudget);
  }

  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return localDataSource.getExpensesTotalInRange(
      budgetId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
