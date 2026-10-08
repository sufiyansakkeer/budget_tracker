import '../../../../core/domain/entities/budget_entity.dart';
import '../entities/committed_spending.dart';
import '../entities/recent_expense_entity.dart';

/// Contract for dashboard data operations.
abstract class DashboardRepository {
  /// Returns the most recent expenses up to [limit], optionally scoped to
  /// a single [budgetId].
  Future<List<RecentExpenseEntity>> getRecentExpenses({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  });

  /// Committed spending (expenses with a `bill_id`) per budget id, for every
  /// budget in [budgets]: the period total uses calendar-day bounds of the
  /// budget's start and end, the today total covers [today]'s calendar day
  /// and is 0 when [today] is outside the period. Budgets without committed
  /// expenses map to [CommittedSpending.zero].
  Future<Map<String, CommittedSpending>> getCommittedSpending({
    required List<BudgetEntity> budgets,
    required DateTime today,
  });
}
