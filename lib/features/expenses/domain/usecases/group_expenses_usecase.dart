import '../entities/expense_entity.dart';
import '../entities/expense_group.dart';
import '../entities/expense_history_sort.dart';
import 'sort_expenses_usecase.dart';
import '../../../../core/dates/calendar_dates.dart';

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
    final today = now.dateOnly;
    final yesterday = today.addDays(-1);
    final buckets = <DateTime, List<ExpenseEntity>>{};

    for (final expense in expenses) {
      final date = (expense.date.toLocal()).dateOnly;
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
  /// option. The category sort keeps the incoming order, which
  /// [SortExpensesUseCase] has already arranged by category name.
  void _sortWithinGroup(List<ExpenseEntity> items, ExpenseSortOption sort) {
    if (sort == ExpenseSortOption.category) return;
    items.sort(SortExpensesUseCase.comparatorFor(sort));
  }

  ExpenseGroupType _typeFor(DateTime date, DateTime today, DateTime yesterday) {
    if (_sameDay(date, today)) return ExpenseGroupType.today;
    if (_sameDay(date, yesterday)) return ExpenseGroupType.yesterday;
    return ExpenseGroupType.earlier;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
