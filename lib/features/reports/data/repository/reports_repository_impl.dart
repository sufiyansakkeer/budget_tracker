import '../../../../core/domain/entities/budget_entity.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/domain/entities/expense_failure.dart';
import '../../../expenses/domain/entities/expense_history_filter.dart';
import '../../../expenses/domain/usecases/filter_expenses_usecase.dart';
import '../../../expenses/domain/usecases/get_categories_usecase.dart';
import '../../../expenses/domain/usecases/get_expenses_usecase.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/repository/reports_repository.dart';

/// Concrete [ReportsRepository] backed by the existing expense and budget
/// repositories. No report calculations are performed here.
class ReportsRepositoryImpl implements ReportsRepository {
  final GetExpensesUseCase getExpensesUseCase;
  final GetCategoriesUseCase getCategoriesUseCase;
  final FilterExpensesUseCase filterExpensesUseCase;
  final BudgetRepository budgetRepository;

  ReportsRepositoryImpl({
    required this.getExpensesUseCase,
    required this.getCategoriesUseCase,
    required this.filterExpensesUseCase,
    required this.budgetRepository,
  });

  @override
  ReportRange resolveRange(
    ReportPeriod period, {
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case ReportPeriod.thisWeek:
        final start = _startOfWeek(today);
        return ReportRange(start: start, end: today, period: period);
      case ReportPeriod.lastWeek:
        final thisStart = _startOfWeek(today);
        final lastStart = thisStart.subtract(const Duration(days: 7));
        final lastEnd = thisStart.subtract(const Duration(days: 1));
        return ReportRange(start: lastStart, end: lastEnd, period: period);
      case ReportPeriod.thisMonth:
        return ReportRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
          period: period,
        );
      case ReportPeriod.lastMonth:
        final firstOfThis = DateTime(now.year, now.month, 1);
        final lastMonthStart = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = firstOfThis.subtract(const Duration(days: 1));
        return ReportRange(
          start: lastMonthStart,
          end: lastMonthEnd,
          period: period,
        );
      case ReportPeriod.thisYear:
        return ReportRange(
          start: DateTime(now.year, 1, 1),
          end: today,
          period: period,
        );
      case ReportPeriod.custom:
        final start = customStart ?? today;
        final end = customEnd ?? today;
        ReportRange? range;
        try {
          range = ReportRange(
            start: DateTime(start.year, start.month, start.day),
            end: DateTime(end.year, end.month, end.day),
            period: period,
          );
        } catch (_) {
          range = ReportRange(start: today, end: today, period: period);
        }
        return range;
    }
  }

  @override
  Future<List<ExpenseEntity>> getFilteredExpenses(
    ExpenseHistoryFilter filter,
  ) async {
    final activeId = await budgetRepository.getActiveBudgetId();
    final result = await getExpensesUseCase(budgetId: activeId);
    if (result case ExpenseError(:final failure)) {
      throw Exception(failure.message);
    }
    final expenses = (result as ExpenseSuccess).data;
    return filterExpensesUseCase(expenses: expenses, filter: filter);
  }

  @override
  Future<List<ExpenseCategory>> getCategories() async {
    final result = await getCategoriesUseCase();
    if (result case ExpenseError(:final failure)) {
      throw Exception(failure.message);
    }
    return (result as ExpenseSuccess).data;
  }

  @override
  Future<BudgetEntity?> getCurrentBudget() {
    return budgetRepository.getActiveBudget();
  }

  @override
  Future<double> getCurrentMonthSpent() async {
    final activeId = await budgetRepository.getActiveBudgetId();
    if (activeId == null) return 0;
    final stats = await budgetRepository.getBudgetStatistics(
      activeId,
      referenceDate: DateTime.now(),
    );
    return stats.totalSpent;
  }

  DateTime _startOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }
}
