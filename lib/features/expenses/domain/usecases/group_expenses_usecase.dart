import '../entities/expense_entity.dart';
import '../entities/expense_group.dart';

/// Groups expenses into time buckets: Today, Yesterday, This Week,
/// Last Week, This Month, Earlier.
///
/// Groups are returned sorted by recency (Today first).
class GroupExpensesUseCase {
  const GroupExpensesUseCase();

  List<ExpenseGroup> call(List<ExpenseEntity> expenses) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));

    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final startOfThisMonth = DateTime(now.year, now.month, 1);

    final buckets = <ExpenseGroupType, List<ExpenseEntity>>{
      ExpenseGroupType.today: [],
      ExpenseGroupType.yesterday: [],
      ExpenseGroupType.thisWeek: [],
      ExpenseGroupType.lastWeek: [],
      ExpenseGroupType.thisMonth: [],
      ExpenseGroupType.earlier: [],
    };

    for (final expense in expenses) {
      final date = _dateOnly(expense.date);
      final ExpenseGroupType type;

      if (_sameDay(date, today)) {
        type = ExpenseGroupType.today;
      } else if (_sameDay(date, yesterday)) {
        type = ExpenseGroupType.yesterday;
      } else if (!date.isBefore(startOfThisWeek)) {
        type = ExpenseGroupType.thisWeek;
      } else if (!date.isBefore(startOfLastWeek)) {
        type = ExpenseGroupType.lastWeek;
      } else if (!date.isBefore(startOfThisMonth)) {
        type = ExpenseGroupType.thisMonth;
      } else {
        type = ExpenseGroupType.earlier;
      }

      buckets[type]!.add(expense);
    }

    final groups = <ExpenseGroup>[];
    for (final type in ExpenseGroupType.values) {
      final items = buckets[type]!;
      if (items.isEmpty) continue;
      // Within a group, sort newest first.
      items.sort((a, b) => b.date.compareTo(a.date));
      groups.add(ExpenseGroup(type: type, expenses: items));
    }
    groups.sort((a, b) => a.type.order.compareTo(b.type.order));
    return groups;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
