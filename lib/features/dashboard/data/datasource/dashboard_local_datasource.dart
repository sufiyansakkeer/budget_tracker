import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/entities/committed_spending.dart';
import '../../domain/entities/recent_expense_entity.dart';

/// Contract for local data source operations for the dashboard.
abstract class DashboardLocalDataSource {
  /// Returns the most recent expenses up to [limit], optionally scoped to
  /// a single [budgetId].
  Future<List<RecentExpenseEntity>> getRecentExpenses({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  });

  /// See [DashboardRepository.getCommittedSpending].
  Future<Map<String, CommittedSpending>> getCommittedSpending({
    required List<BudgetEntity> budgets,
    required DateTime today,
  });

  /// Discretionary spending (expenses without a `bill_id`) of budget
  /// [budgetId] per calendar day from [start] through [end], whole days.
  /// Days without spending are absent.
  Future<Map<DateTime, double>> getDailyDiscretionarySpending({
    required String budgetId,
    required DateTime start,
    required DateTime end,
  });
}
