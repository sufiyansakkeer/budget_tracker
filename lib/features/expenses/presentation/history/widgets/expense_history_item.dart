import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../../core/widgets/app_money.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../widgets/category_visuals.dart';
import '../../widgets/transaction_row.dart';
import '../../../../../core/dates/date_range_format.dart';

/// A single expense row in the history list: a [TransactionRow] showing
/// the time (the day is in the group header above it).
///
/// Tapping opens the expense; pressing and holding offers edit, duplicate,
/// move and delete.
class ExpenseHistoryItem extends StatelessWidget {
  final ExpenseEntity expense;
  final ExpenseCategory? category;
  final VoidCallback? onTap;

  /// Press-and-hold opens contextual actions (edit, duplicate, move, delete).
  final VoidCallback? onLongPress;

  /// Budget name to display in combined mode (null = single budget mode).
  final String? budgetName;

  /// Callback when the info icon is tapped (combined mode).
  final VoidCallback? onInfoTap;

  /// Currency code used to format the amount.
  final String? currency;

  const ExpenseHistoryItem({
    super.key,
    required this.expense,
    this.category,
    this.onTap,
    this.onLongPress,
    this.budgetName,
    this.onInfoTap,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category != null
        ? CategoryVisuals.adaptiveColor(context, category!.colorHex)
        : theme.colorScheme.onSurfaceVariant;
    final icon = category != null
        ? CategoryVisuals.iconFor(category!.icon)
        : Icons.category_rounded;
    final categoryName = category?.name ?? 'Uncategorised';
    final note = expense.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final time = AppDates.time(context, expense.time);
    final amount = AppMoney.format(expense.amount, currency: currency);

    final row = TransactionRow(
      icon: icon,
      color: color,
      title: hasNote ? note : categoryName,
      detail: hasNote ? categoryName : null,
      when: time,
      amount: expense.amount,
      currency: currency,
      hasReceipt: expense.receiptImagePath != null,
      budgetName: budgetName,
      action: onInfoTap == null
          ? null
          : IconButton(
              onPressed: onInfoTap,
              tooltip: infoActionLabel,
              icon: Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      semanticLabel:
          '${hasNote ? '$note, $categoryName' : categoryName}, $amount, '
          '$time${budgetName != null ? ', budget $budgetName' : ''}'
          '${expense.receiptImagePath != null ? ', receipt attached' : ''}',
      onTap: onTap,
      onLongPress: onLongPress,
    );
    // The row is one node for a screen reader, which hides the info
    // button inside it; the same action is offered on the row instead.
    final info = onInfoTap;
    if (info == null) return row;
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: infoActionLabel): info,
      },
      child: row,
    );
  }

  /// The row's screen-reader action for [onInfoTap].
  static const infoActionLabel = 'Expense and budget details';
}
