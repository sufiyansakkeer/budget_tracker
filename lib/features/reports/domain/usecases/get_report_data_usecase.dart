import '../../../../core/domain/entities/budget_entity.dart';
import '../../../expenses/domain/entities/expense_history_filter.dart';
import '../entities/report_failure.dart';
import '../entities/report_period.dart';
import '../repository/reports_repository.dart';
import '../services/analytics_service.dart';

/// Loads all data needed to render the reports screen and computes report
/// analytics via [AnalyticsService].
class GetReportDataUseCase {
  final ReportsRepository repository;
  final AnalyticsService analyticsService;

  GetReportDataUseCase({
    required this.repository,
    required this.analyticsService,
  });

  Future<ReportDataResult> call({
    required ReportPeriod period,
    ExpenseHistoryFilter filter = const ExpenseHistoryFilter(),
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    try {
      final range = repository.resolveRange(
        period,
        referenceDate: referenceDate,
        customStart: customStart,
        customEnd: customEnd,
      );

      if (!range.isValid) {
        return const ReportError(
          ReportFailure(
            type: ReportErrorType.invalidRange,
            message: 'The selected date range is invalid.',
          ),
        );
      }

      // Build a date-bounded filter for the selected period.
      final effectiveFrom = filter.dateFrom ?? range.start;
      final effectiveTo = filter.dateTo ?? range.end;
      final boundedFilter = ExpenseHistoryFilter(
        categoryId: filter.categoryId,
        dateFrom: effectiveFrom,
        dateTo: effectiveTo,
        minAmount: filter.minAmount,
        maxAmount: filter.maxAmount,
        tags: filter.tags,
        receiptOnly: filter.receiptOnly,
      );

      final expenses = await repository.getFilteredExpenses(boundedFilter);
      final categories = await repository.getCategories();

      // Current-month budget context only when the range covers the current
      // month; otherwise budget cards are omitted.
      BudgetEntity? currentBudget;
      var currentMonthSpent = 0.0;
      var currentMonthBudget = 0.0;
      if (range.coversCurrentMonth) {
        currentBudget = await repository.getCurrentBudget();
        currentMonthSpent = await repository.getCurrentMonthSpent();
        if (currentBudget != null) {
          currentMonthBudget = currentBudget.monthlyAmount;
        }
      }

      final data = analyticsService.buildReportData(
        range: range,
        filteredExpenses: expenses,
        categories: categories,
        filter: boundedFilter,
        currentBudget: currentBudget,
        currentMonthSpent: currentMonthSpent,
        currentMonthBudget: currentMonthBudget,
      );

      return ReportSuccess(data);
    } catch (e) {
      return ReportError(
        ReportFailure(
          type: ReportErrorType.databaseFailure,
          message: 'Failed to load report: ${e.toString()}',
        ),
      );
    }
  }
}
