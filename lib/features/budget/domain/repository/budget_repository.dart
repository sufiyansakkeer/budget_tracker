import '../../../../core/domain/entities/budget_entity.dart';
import '../entities/budget_analytics_entity.dart';
import '../entities/budget_error.dart';
import '../entities/budget_filter.dart';
import '../entities/budget_summary_entity.dart';
import '../entities/monthly_statistics_entity.dart';

/// Contract for budget data access consumed by use cases and the calculation engine.
abstract class BudgetRepository {
  /// Returns the active budget, or null if none is set.
  Future<BudgetEntity?> getActiveBudget();

  /// Returns the persisted active budget id, or null if not set.
  Future<String?> getActiveBudgetId();

  /// Persists the active budget id.
  Future<void> setActiveBudgetId(String budgetId);

  /// Returns a budget by its id, or null if not found.
  Future<BudgetEntity?> getBudgetById(String id);

  /// Returns all budgets matching the given [options].
  Future<List<BudgetEntity>> getAllBudgets({BudgetQueryOptions? options});

  /// Creates a new budget.
  Future<BudgetEntity> createBudget(BudgetEntity budget);

  /// Updates an existing budget.
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
    DateTime? referenceDate,
  });

  /// Returns total spending for [referenceDate]'s calendar day within the budget.
  Future<double> getTodaySpending(String budgetId, {DateTime? referenceDate});

  /// Returns remaining days in the budget period including today.
  Future<int> getRemainingDays(String budgetId, {DateTime? referenceDate});

  /// Builds calculation input from repository data for the given budget.
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  });

  /// Updates the budget's remaining amount based on current spending.
  Future<void> updateBudgetRemainingAmount(String budgetId);

  /// Returns total spending within an explicit date range for a specific budget.
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  });
}

/// Bundled raw data used by use cases before invoking [BudgetCalculationService].
class BudgetCalculationContext {
  final BudgetEntity budget;
  final MonthlyStatisticsEntity statistics;
  final DateTime referenceDate;

  const BudgetCalculationContext({
    required this.budget,
    required this.statistics,
    required this.referenceDate,
  });
}

/// Type alias re-export for convenience in repository consumers.
typedef BudgetSummaryResult = BudgetResult<BudgetSummaryEntity>;
typedef BudgetAnalyticsResult = BudgetResult<BudgetAnalyticsEntity>;
