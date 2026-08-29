import '../entities/expense_entity.dart';
import '../entities/expense_group.dart';
import '../entities/expense_history_sort.dart';

/// Groups expenses by their local calendar date.
///
/// Date groups are always ordered newest-first (Today → Yesterday → earlier).
/// Within each group expenses are sorted by [sort].
class GroupExpensesUseCase {
  const GroupExpensesUseCase();

  List<ExpenseGroup> call(
    List<ExpenseEntity> expenses, {
    ExpenseSortOption sort = ExpenseSortOption.newestFirst,
  }) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final buckets = <DateTime, List<ExpenseEntity>>{};

    for (final expense in expenses) {
      final date = _dateOnly(expense.date.toLocal());
      buckets.putIfAbsent(date, () => []).add(expense);
    }

    final dates = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    final groups = dates.map((date) {
      final items = List<ExpenseEntity>.from(buckets[date]!);
      _sortWithinGroup(items, sort);
      final type = _typeFor(date, today, yesterday);
      return ExpenseGroup(type: type, date: date, expenses: items);
    }).toList();
    return groups;
  }

  /// Sorts items within a single date group according to the active sort
  /// option. Amount/category/alphabetical sorts apply within the group;
  /// chronological sorts use date+time.
  void _sortWithinGroup(List<ExpenseEntity> items, ExpenseSortOption sort) {
    switch (sort) {
      case ExpenseSortOption.newestFirst:
        items.sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          if (byDate != 0) return byDate;
          return b.time.compareTo(a.time);
        });
        break;
      case ExpenseSortOption.oldestFirst:
        items.sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          if (byDate != 0) return byDate;
          return a.time.compareTo(b.time);
        });
        break;
      case ExpenseSortOption.highestAmount:
        items.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case ExpenseSortOption.lowestAmount:
        items.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case ExpenseSortOption.category:
        items.sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          if (byDate != 0) return byDate;
          return b.time.compareTo(a.time);
        });
        break;
      case ExpenseSortOption.alphabetical:
        items.sort((a, b) {
          final na = (a.note ?? '').toLowerCase();
          final nb = (b.note ?? '').toLowerCase();
          final byNote = na.compareTo(nb);
          if (byNote != 0) return byNote;
          return b.date.compareTo(a.date);
        });
        break;
    }
  }

  ExpenseGroupType _typeFor(DateTime date, DateTime today, DateTime yesterday) {
    if (_sameDay(date, today)) return ExpenseGroupType.today;
    if (_sameDay(date, yesterday)) return ExpenseGroupType.yesterday;
    return ExpenseGroupType.earlier;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
