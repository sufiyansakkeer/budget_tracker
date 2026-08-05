import '../entities/recent_expense_entity.dart';

/// Contract for dashboard data operations.
abstract class DashboardRepository {
  /// Returns the most recent expenses up to [limit].
  Future<List<RecentExpenseEntity>> getRecentExpenses({
    int limit = 5,
    DateTime? referenceDate,
  });
}
