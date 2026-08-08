import '../entities/recent_expense_entity.dart';
import '../repository/dashboard_repository.dart';

/// Retrieves recent expenses for dashboard display.
class GetRecentExpensesUseCase {
  final DashboardRepository repository;

  GetRecentExpensesUseCase({required this.repository});

  Future<List<RecentExpenseEntity>> call({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  }) {
    return repository.getRecentExpenses(
      limit: limit,
      referenceDate: referenceDate,
      budgetId: budgetId,
    );
  }
}
