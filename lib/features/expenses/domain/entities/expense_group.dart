import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import 'expense_entity.dart';

/// Kept for compatibility with callers that need to identify relative groups.
enum ExpenseGroupType {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  earlier;

  /// Human-readable label for the group header.
  String get label {
    switch (this) {
      case ExpenseGroupType.today:
        return 'Today';
      case ExpenseGroupType.yesterday:
        return 'Yesterday';
      case ExpenseGroupType.thisWeek:
        return 'This Week';
      case ExpenseGroupType.lastWeek:
        return 'Last Week';
      case ExpenseGroupType.thisMonth:
        return 'This Month';
      case ExpenseGroupType.earlier:
        return 'Earlier';
    }
  }

  /// Ordering used when rendering groups (Today first).
  int get order {
    switch (this) {
      case ExpenseGroupType.today:
        return 0;
      case ExpenseGroupType.yesterday:
        return 1;
      case ExpenseGroupType.thisWeek:
        return 2;
      case ExpenseGroupType.lastWeek:
        return 3;
      case ExpenseGroupType.thisMonth:
        return 4;
      case ExpenseGroupType.earlier:
        return 5;
    }
  }
}

/// A named group of expenses sharing one local calendar date.
class ExpenseGroup extends Equatable {
  final ExpenseGroupType type;
  final DateTime? date;
  final List<ExpenseEntity> expenses;

  const ExpenseGroup({required this.type, this.date, required this.expenses});

  String get label {
    final groupDate = date;
    if (groupDate == null) return type.label;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_sameDay(groupDate, today)) return 'Today';
    if (_sameDay(groupDate, today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('d MMM yyyy').format(groupDate);
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  double get totalAmount => expenses.fold(0.0, (sum, e) => sum + e.amount);

  @override
  List<Object?> get props => [type, date, expenses];
}
