import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/entities/committed_spending.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../../domain/repository/dashboard_repository.dart';
import '../datasource/dashboard_local_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardLocalDataSource localDataSource;

  DashboardRepositoryImpl({required this.localDataSource});

  @override
  Future<List<RecentExpenseEntity>> getRecentExpenses({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  }) {
    return localDataSource.getRecentExpenses(
      limit: limit,
      referenceDate: referenceDate,
      budgetId: budgetId,
    );
  }

  @override
  Future<Map<String, CommittedSpending>> getCommittedSpending({
    required List<BudgetEntity> budgets,
    required DateTime today,
  }) {
    return localDataSource.getCommittedSpending(budgets: budgets, today: today);
  }

  @override
  Future<Map<DateTime, double>> getDailyDiscretionarySpending({
    required String budgetId,
    required DateTime start,
    required DateTime end,
  }) {
    return localDataSource.getDailyDiscretionarySpending(
      budgetId: budgetId,
      start: start,
      end: end,
    );
  }
}
