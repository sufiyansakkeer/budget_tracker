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
  }) {
    return localDataSource.getRecentExpenses(
      limit: limit,
      referenceDate: referenceDate,
    );
  }
}
