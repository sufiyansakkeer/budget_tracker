import '../entities/expense_entity.dart';
import '../entities/expense_group.dart';

/// Groups expenses by their local calendar date.
///
/// Groups and expenses within each group are returned newest first.
class GroupExpensesUseCase {
  const GroupExpensesUseCase();

  List<ExpenseGroup> call(List<ExpenseEntity> expenses) {
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
      final items = buckets[date]!..sort((a, b) => b.time.compareTo(a.time));
      final type = _typeFor(date, today, yesterday);
      return ExpenseGroup(type: type, date: date, expenses: items);
    }).toList();
    return groups;
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
