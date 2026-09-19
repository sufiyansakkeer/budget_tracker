import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../domain/entities/expense_group.dart';

/// Section header for a group of expenses sharing one calendar date.
class ExpenseGroupHeader extends StatelessWidget {
  final ExpenseGroup group;
  final String? currency;

  const ExpenseGroupHeader({super.key, required this.group, this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = group.expenses.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                group.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            CurrencyFormatter.format(
              group.totalAmount,
              code: currency,
              decimalDigits: 0,
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$count ${count == 1 ? 'item' : 'items'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
