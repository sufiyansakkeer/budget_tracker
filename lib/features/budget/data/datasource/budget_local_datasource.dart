import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/entities/budget_filter.dart';
import '../../domain/entities/monthly_statistics_entity.dart';

/// Local data access for budget and expense queries.
abstract class BudgetLocalDataSource {
  /// Returns the persisted active budget id, or null if not set.
  Future<String?> getActiveBudgetId();

  /// Persists the active budget id.
  Future<void> setActiveBudgetId(String budgetId);

  /// Returns a budget by its id, or null if not found.
  Future<BudgetEntity?> getBudgetById(String id);

  /// Returns all budgets matching the given [options].
  Future<List<BudgetEntity>> getAllBudgets({BudgetQueryOptions? options});

  /// Creates a new budget and returns it.
  Future<BudgetEntity> createBudget(BudgetEntity budget);

  /// Updates an existing budget and returns the updated value.
  Future<BudgetEntity> updateBudget(BudgetEntity budget);

  /// Deletes a budget and its associated expenses.
  Future<void> deleteBudget(String id);

  /// Archives or restores a budget.
  Future<BudgetEntity> setBudgetArchived(String id, {required bool archived});

  /// Duplicates a budget (without expenses) and returns the new budget.
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Returns aggregated expense statistics for the given budget.
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    required DateTime referenceDate,
  });

  /// Returns total spending for [referenceDate]'s calendar day within the budget.
  Future<double> getTodaySpending(String budgetId, {DateTime? referenceDate});

  /// Returns remaining days in the budget period including today.
  Future<int> getRemainingDays(String budgetId, {DateTime? referenceDate});

  /// Returns total spending within an explicit date range for a specific budget.
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  });
}
