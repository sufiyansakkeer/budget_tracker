import '../../../../core/domain/entities/budget_entity.dart';

/// How the bills screens name and offer the budget a bill is paid from.
///
/// Pure, with [today] passed in, so the labels and picker contents are
/// testable on fixed dates.
class BillBudgetLink {
  BillBudgetLink._();

  /// "Not linked" is the picker's first item and the label for a bill
  /// without a budget.
  static const String notLinked = 'Not linked';

  /// Helper under the picker.
  static const String pickerHelper =
      "Set aside from this budget until it's paid";

  /// The budget's name, marked "· archived" or "· ended" when it can no
  /// longer set the bill aside.
  static String budgetLabel(BudgetEntity budget, DateTime today) {
    if (budget.isArchived) return '${budget.name} · archived';
    if (_date(budget.endDate).isBefore(_date(today))) {
      return '${budget.name} · ended';
    }
    return budget.name;
  }

  /// Budgets a bill can be linked to on [today]: not archived and not ended
  /// (running or upcoming), earliest start first. The budget [currentId]
  /// points to is always included, even when ended or archived, so editing
  /// a bill never drops its link silently.
  static List<BudgetEntity> pickerOptions(
    List<BudgetEntity> budgets, {
    String? currentId,
    required DateTime today,
  }) {
    final day = _date(today);
    final options =
        budgets
            .where(
              (b) =>
                  b.id == currentId ||
                  (!b.isArchived && !_date(b.endDate).isBefore(day)),
            )
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return options;
  }

  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);
}
