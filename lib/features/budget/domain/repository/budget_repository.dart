import '../../../../core/domain/entities/budget_entity.dart';
import '../entities/budget_analytics_entity.dart';
import '../entities/budget_error.dart';
import '../entities/budget_summary_entity.dart';
import '../entities/monthly_statistics_entity.dart';

/// Contract for budget data access consumed by use cases and the calculation engine.
abstract class BudgetRepository {
  /// Returns the budget for the current calendar month, or null if none exists.
  Future<BudgetEntity?> getCurrentBudget();

  /// Returns aggregated expense statistics for the given month and year.
  Future<MonthlyStatisticsEntity> getMonthlyStatistics({
    required int month,
    required int year,
    DateTime? referenceDate,
  });

  /// Returns total spending for [referenceDate]'s calendar day.
  Future<double> getTodaySpending({DateTime? referenceDate});

  /// Returns remaining days in the budget month including today.
  Future<int> getRemainingDays({DateTime? referenceDate});

  /// Builds calculation input from repository data for the current budget.
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext({
    DateTime? referenceDate,
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
