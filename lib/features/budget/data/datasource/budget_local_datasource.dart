import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/entities/monthly_statistics_entity.dart';

/// Local data access for budget and expense queries.
abstract class BudgetLocalDataSource {
  Future<BudgetEntity?> getBudgetForMonth({required int month, required int year});

  Future<MonthlyStatisticsEntity> getMonthlyStatistics({
    required int month,
    required int year,
    required DateTime referenceDate,
  });
}
