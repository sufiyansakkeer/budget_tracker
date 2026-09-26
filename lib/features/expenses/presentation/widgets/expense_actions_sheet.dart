import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import 'category_visuals.dart';

/// Contextual actions for one expense (opened by press-and-hold on a row).
enum ExpenseRowAction { edit, duplicate, move, delete }

/// Bottom sheet listing what can be done with an expense without opening
/// its details. Returns the chosen action or null.
abstract final class ExpenseActionsSheet {
  static Future<ExpenseRowAction?> show(
    BuildContext context, {
    required ExpenseEntity expense,
    ExpenseCategory? category,
    String? currency,
  }) {
    return AppBottomSheet.show<ExpenseRowAction>(
      context: context,
      builder: (context) => _ExpenseActionsBody(
        expense: expense,
        category: category,
        currency: currency,
      ),
    );
  }
}

class _ExpenseActionsBody extends StatelessWidget {
  final ExpenseEntity expense;
  final ExpenseCategory? category;
  final String? currency;

  const _ExpenseActionsBody({
    required this.expense,
    required this.category,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category != null
        ? CategoryVisuals.adaptiveColor(context, category!.colorHex)
        : theme.colorScheme.onSurfaceVariant;
    final title = (expense.note?.trim().isNotEmpty ?? false)
        ? expense.note!.trim()
        : category?.name ?? 'Expense';
    final subtitle =
        '${CurrencyFormatter.format(expense.amount, code: currency)} · '
        '${category?.name ?? 'Uncategorised'} · '
        '${DateFormat('d MMM').format(expense.date)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconTile(
                icon: CategoryVisuals.iconFor(category?.icon ?? 'category'),
                color: color,
                size: AppSizes.avatarMd,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: AppSpacing.md),
        _action(
          context,
          key: const Key('expenseAction_edit'),
          icon: Icons.edit_outlined,
          label: 'Edit',
          action: ExpenseRowAction.edit,
        ),
        _action(
          context,
          key: const Key('expenseAction_duplicate'),
          icon: Icons.content_copy_rounded,
          label: 'Duplicate',
          hint: 'Start a new expense with the same details',
          action: ExpenseRowAction.duplicate,
        ),
        _action(
          context,
          key: const Key('expenseAction_move'),
          icon: Icons.drive_file_move_outlined,
          label: 'Move to another budget',
          action: ExpenseRowAction.move,
        ),
        _action(
          context,
          key: const Key('expenseAction_delete'),
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          hint: 'You can undo for a few seconds',
          action: ExpenseRowAction.delete,
          destructive: true,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _action(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    String? hint,
    required ExpenseRowAction action,
    bool destructive = false,
  }) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;
    return ListTile(
      key: key,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      subtitle: hint != null ? Text(hint) : null,
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
