import 'package:equatable/equatable.dart';

import 'expense_entity.dart';

/// Time buckets used to group expenses on the history screen.
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

/// A named group of expenses sharing the same time bucket.
class ExpenseGroup extends Equatable {
  final ExpenseGroupType type;
  final List<ExpenseEntity> expenses;

  const ExpenseGroup({required this.type, required this.expenses});

  double get totalAmount => expenses.fold(0.0, (sum, e) => sum + e.amount);

  @override
  List<Object?> get props => [type, expenses];
}
