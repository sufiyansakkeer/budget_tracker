import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_money.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../../expenses/presentation/widgets/transaction_row.dart';
import '../../domain/entities/recent_expense_entity.dart';

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
    final when = _when(expense.date, today ?? DateTime.now());
    return TransactionRow(
      icon: CategoryVisuals.iconFor(expense.categoryIcon),
      color: CategoryVisuals.adaptiveColor(context, expense.categoryColorHex),
      title: title,
      detail: expense.categoryName,
      when: when,
      amount: expense.amount,
      currency: currency,
      semanticLabel:
          '$title, ${expense.categoryName}, '
          '${AppMoney.format(expense.amount, currency: currency)}, $when',
      onTap: onTap,
    );
  }

  /// "12:40 PM" today, "Yesterday, 7:30 PM", otherwise "6 Oct".
  static String _when(DateTime date, DateTime now) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final time = DateFormat.jm().format(date);
    if (day == today) return time;
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday, $time';
    }
    return DateFormat('d MMM').format(date);
  }
}
