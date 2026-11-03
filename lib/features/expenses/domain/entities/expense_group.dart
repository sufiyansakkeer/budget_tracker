import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import 'expense_entity.dart';
import '../../../../core/dates/calendar_dates.dart';

/// Which day a group of expenses falls on, relative to today.
enum ExpenseGroupType {
  today,
  yesterday,
  earlier;

  /// Human-readable label for the group header.
  String get label {
    switch (this) {
      case ExpenseGroupType.today:
        return 'Today';
      case ExpenseGroupType.yesterday:
        return 'Yesterday';
      case ExpenseGroupType.earlier:
        return 'Earlier';
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
    if (_sameDay(groupDate, today.addDays(-1))) {
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
