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
}
