import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../domain/entities/recent_expense_entity.dart';

/// One recent expense: category tile, what it was, when, and the amount.
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
    final hasNote = expense.note != null && expense.note!.trim().isNotEmpty;
    final title = hasNote ? expense.note!.trim() : expense.categoryName;
    final when = _when(expense.date, today ?? DateTime.now());
    return AppListRow(
      leading: IconTile(
        icon: CategoryVisuals.iconFor(expense.categoryIcon),
        color: CategoryVisuals.adaptiveColor(context, expense.categoryColorHex),
        size: AppSizes.avatarSm,
      ),
      title: title,
      subtitle: '${expense.categoryName} · $when',
      trailing: AppMoney(
        amount: expense.amount,
        currency: currency,
        textAlign: TextAlign.end,
      ),
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
