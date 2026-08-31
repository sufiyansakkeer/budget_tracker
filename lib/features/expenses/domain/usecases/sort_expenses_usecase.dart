import '../entities/expense_category.dart';
import '../entities/expense_entity.dart';
import '../entities/expense_history_sort.dart';

/// Sorts expenses according to an [ExpenseSortOption].
///
/// Returns a new sorted list. The order is stable for equal keys.
class SortExpensesUseCase {
  const SortExpensesUseCase();

  List<ExpenseEntity> call({
    required List<ExpenseEntity> expenses,
    required List<ExpenseCategory> categories,
    required ExpenseSortOption sort,
  }) {
    final result = List.of(expenses);

    final categoryNameById = <String, String>{
      for (final category in categories)
        category.id: category.name.toLowerCase(),
    };

    switch (sort) {
      case ExpenseSortOption.newestFirst:
        result.sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          if (byDate != 0) return byDate;
          return b.time.compareTo(a.time);
        });
        break;
      case ExpenseSortOption.oldestFirst:
        result.sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          if (byDate != 0) return byDate;
          return a.time.compareTo(b.time);
        });
        break;
      case ExpenseSortOption.highestAmount:
        result.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case ExpenseSortOption.lowestAmount:
        result.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case ExpenseSortOption.category:
        result.sort((a, b) {
          final ca = categoryNameById[a.categoryId] ?? '';
          final cb = categoryNameById[b.categoryId] ?? '';
          final byName = ca.compareTo(cb);
          if (byName != 0) return byName;
          return b.date.compareTo(a.date);
        });
        break;
      case ExpenseSortOption.alphabetical:
        result.sort((a, b) {
          final na = (a.note ?? '').toLowerCase();
          final nb = (b.note ?? '').toLowerCase();
          final byNote = na.compareTo(nb);
          if (byNote != 0) return byNote;
          return b.date.compareTo(a.date);
        });
        break;
    }

    return result;
  }
}
