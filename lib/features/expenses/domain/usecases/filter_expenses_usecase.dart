import '../entities/expense_entity.dart';
import '../entities/expense_history_filter.dart';

/// Applies the active [ExpenseHistoryFilter] to a list of expenses.
///
/// All filters are combined with AND semantics. Returns a new list.
///
/// The clauses are composed into one predicate and applied in a single pass:
/// evaluating them one at a time allocated a fresh list per active clause,
/// up to seven copies of the whole expense list on every recompute.
class FilterExpensesUseCase {
  const FilterExpensesUseCase();

  List<ExpenseEntity> call({
    required List<ExpenseEntity> expenses,
    required ExpenseHistoryFilter filter,
  }) {
    if (!filter.isActive) {
      return List.of(expenses);
    }

    final categoryId = filter.categoryId;
    final start = filter.dateFrom == null ? null : _dateOnly(filter.dateFrom!);
    final end = filter.dateTo == null ? null : _dateOnly(filter.dateTo!);
    final minAmount = filter.minAmount;
    final maxAmount = filter.maxAmount;
    // Lower-cased once, not once per expense.
    final tags = filter.tags.map((t) => t.toLowerCase()).toList();
    final receiptOnly = filter.receiptOnly;

    bool matches(ExpenseEntity e) {
      if (categoryId != null && e.categoryId != categoryId) return false;
      if (start != null || end != null) {
        final day = _dateOnly(e.date);
        if (start != null && day.isBefore(start)) return false;
        if (end != null && day.isAfter(end)) return false;
      }
      if (minAmount != null && e.amount < minAmount) return false;
      if (maxAmount != null && e.amount > maxAmount) return false;
      if (tags.isNotEmpty) {
        final expenseTags = e.tags.map((t) => t.toLowerCase()).toSet();
        if (!tags.every(expenseTags.contains)) return false;
      }
      if (receiptOnly &&
          (e.receiptImagePath == null || e.receiptImagePath!.isEmpty)) {
        return false;
      }
      return true;
    }

    return expenses.where(matches).toList();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
