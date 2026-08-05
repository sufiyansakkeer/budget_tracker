import '../entities/expense_entity.dart';
import '../entities/expense_history_filter.dart';

/// Applies the active [ExpenseHistoryFilter] to a list of expenses.
///
/// All filters are combined with AND semantics. Returns a new list.
class FilterExpensesUseCase {
  const FilterExpensesUseCase();

  List<ExpenseEntity> call({
    required List<ExpenseEntity> expenses,
    required ExpenseHistoryFilter filter,
  }) {
    if (!filter.isActive) {
      return List.of(expenses);
    }

    List<ExpenseEntity> result = expenses;

    if (filter.categoryId != null) {
      result = result.where((e) => e.categoryId == filter.categoryId).toList();
    }

    if (filter.dateFrom != null) {
      final start = _dateOnly(filter.dateFrom!);
      result = result.where((e) => !_dateOnly(e.date).isBefore(start)).toList();
    }

    if (filter.dateTo != null) {
      final end = _dateOnly(filter.dateTo!);
      result = result.where((e) => !_dateOnly(e.date).isAfter(end)).toList();
    }

    if (filter.minAmount != null) {
      result = result.where((e) => e.amount >= filter.minAmount!).toList();
    }

    if (filter.maxAmount != null) {
      result = result.where((e) => e.amount <= filter.maxAmount!).toList();
    }

    if (filter.tags.isNotEmpty) {
      result = result.where((e) {
        final expenseTags = e.tags.map((t) => t.toLowerCase()).toSet();
        return filter.tags.every((t) => expenseTags.contains(t.toLowerCase()));
      }).toList();
    }

    if (filter.receiptOnly) {
      result = result
          .where(
            (e) => e.receiptImagePath != null && e.receiptImagePath!.isNotEmpty,
          )
          .toList();
    }

    return result;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
