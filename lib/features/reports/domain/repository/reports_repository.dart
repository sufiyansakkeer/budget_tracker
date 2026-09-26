import '../../../../core/domain/entities/budget_entity.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/domain/entities/expense_history_filter.dart';
import '../entities/report_period.dart';

/// Contract for report data access.
///
/// Reuses the existing expense repository and budget engine — no calculation
/// is duplicated here.
abstract class ReportsRepository {
  /// Returns the [ReportRange] resolved for [period] (optionally [customStart]
  /// and [customEnd] when period is custom).
  ReportRange resolveRange(
    ReportPeriod period, {
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
  });

  /// Expenses of the active budget matching [filter].
  ///
  /// The filter's date range is pushed into SQL, so a one-week report does
  /// not read a budget's whole history; the remaining clauses (category,
  /// amount, tags, receipt) are applied in Dart.
  Future<List<ExpenseEntity>> getFilteredExpenses(ExpenseHistoryFilter filter);

  /// Loads all categories.
  Future<List<ExpenseCategory>> getCategories();

  /// Returns the active budget, if one exists.
  Future<BudgetEntity?> getCurrentBudget();

  /// Returns the total spending for the active budget.
  Future<double> getCurrentMonthSpent();
}
