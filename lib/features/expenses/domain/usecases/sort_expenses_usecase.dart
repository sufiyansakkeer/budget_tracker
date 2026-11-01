import '../entities/expense_category.dart';
import '../entities/expense_entity.dart';
import '../entities/expense_history_sort.dart';

/// Sorts expenses according to an [ExpenseSortOption].
///
/// Returns a new sorted list.
class SortExpensesUseCase {
  const SortExpensesUseCase();

  List<ExpenseEntity> call({
    required List<ExpenseEntity> expenses,
    required List<ExpenseCategory> categories,
    required ExpenseSortOption sort,
  }) {
    final categoryNameById = <String, String>{
      for (final category in categories)
        category.id: category.name.toLowerCase(),
    };
    return List.of(expenses)
      ..sort(comparatorFor(sort, categoryNames: categoryNameById));
  }

  /// How [sort] orders two expenses. [categoryNames] (id → lower-case name)
  /// is read by the category sort only.
  static Comparator<ExpenseEntity> comparatorFor(
    ExpenseSortOption sort, {
    Map<String, String> categoryNames = const {},
  }) => switch (sort) {
    ExpenseSortOption.newestFirst => (a, b) => _byDateTime(b, a),
    ExpenseSortOption.oldestFirst => _byDateTime,
    ExpenseSortOption.highestAmount => (a, b) => b.amount.compareTo(a.amount),
    ExpenseSortOption.lowestAmount => (a, b) => a.amount.compareTo(b.amount),
    ExpenseSortOption.category => (a, b) {
      final byName = (categoryNames[a.categoryId] ?? '').compareTo(
        categoryNames[b.categoryId] ?? '',
      );
      return byName != 0 ? byName : b.date.compareTo(a.date);
    },
    ExpenseSortOption.alphabetical => (a, b) {
      final byNote = (a.note ?? '').toLowerCase().compareTo(
        (b.note ?? '').toLowerCase(),
      );
      return byNote != 0 ? byNote : b.date.compareTo(a.date);
    },
  };

  static int _byDateTime(ExpenseEntity a, ExpenseEntity b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.time.compareTo(b.time);
  }
}
