import 'package:flutter/material.dart';

import '../../../../core/widgets/app_money.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../../expenses/presentation/widgets/transaction_row.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../../../../core/dates/date_range_format.dart';

/// One recent expense on Home, as the same [TransactionRow] Expenses uses,
/// with a relative time ("Yesterday, 7:30 PM").
///
/// Amounts carry no minus sign: everything here is spending, so a sign
/// would only add noise (refunds would get a "+").
class RecentExpenseTile extends StatelessWidget {
  final RecentExpenseEntity expense;
  final String currency;

  /// "Today" for the relative time; defaults to the device clock.
  final DateTime? today;
  final VoidCallback? onTap;

  const RecentExpenseTile({
    super.key,
    required this.expense,
    required this.currency,
    this.today,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final note = expense.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final title = hasNote ? note : expense.categoryName;
    final when = _when(context, expense.date, today ?? DateTime.now());
    return TransactionRow(
      icon: CategoryVisuals.iconFor(expense.categoryIcon),
      color: CategoryVisuals.adaptiveColor(context, expense.categoryColorHex),
      title: title,
      // Without a note the title already is the category: never say it twice.
      detail: hasNote ? expense.categoryName : null,
      when: when,
      amount: expense.amount,
      currency: currency,
      semanticLabel: [
        title,
        if (hasNote) expense.categoryName,
        AppMoney.format(expense.amount, currency: currency),
        when,
      ].join(', '),
      onTap: onTap,
    );
  }

  /// "12:40 PM" today (in the device's 12/24-hour format), "Yesterday,
  /// 7:30 PM", otherwise "6 Oct" ("6 Oct 2025" in another year).
  static String _when(BuildContext context, DateTime date, DateTime now) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final time = AppDates.time(context, date);
    if (day == today) return time;
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday, $time';
    }
    return AppDates.day(date, now: now);
  }
}
