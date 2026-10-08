import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_header.dart';

/// The date checks the add and edit screens share, so quick add and the
/// full form word them the same way.
abstract final class ExpenseDateRules {
  /// "Outside the Personal budget period (8 Oct – 7 Nov)." when [date] is
  /// not a calendar day of [budget]'s period; null when it is, or when
  /// either is unknown.
  static String? outsideBudget(DateTime? date, BudgetEntity? budget) {
    if (date == null || budget == null) return null;
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      budget.startDate.year,
      budget.startDate.month,
      budget.startDate.day,
    );
    final end = DateTime(
      budget.endDate.year,
      budget.endDate.month,
      budget.endDate.day,
    );
    if (day.isBefore(start) || day.isAfter(end)) {
      return 'Outside the ${budget.name} budget period '
          '(${formatShortDateRange(budget.startDate, budget.endDate)}).';
    }
    return null;
  }
}
