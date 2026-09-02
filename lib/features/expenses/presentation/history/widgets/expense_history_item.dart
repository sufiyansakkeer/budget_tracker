import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../widgets/category_visuals.dart';
import '../../../../../core/theme/app_colors_extension.dart';

/// Animated tile for a single expense in the history list.
///
/// Shows category icon/color, name, amount, date, time, note preview, and a
/// receipt indicator. Tapping it opens the expense details.
///
/// In combined mode, optionally shows a budget name chip and an info icon.
class ExpenseHistoryItem extends StatelessWidget {
  final ExpenseEntity expense;
  final ExpenseCategory? category;
  final VoidCallback? onTap;

  /// Budget name to display in combined mode (null = single budget mode).
  final String? budgetName;

  /// Callback when the info icon is tapped (combined mode).
  final VoidCallback? onInfoTap;

  const ExpenseHistoryItem({
    super.key,
    required this.expense,
    this.category,
    this.onTap,
    this.budgetName,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category != null
        ? CategoryVisuals.colorFor(category!.colorHex)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = category != null
        ? CategoryVisuals.iconFor(category!.icon)
        : Icons.help_outline_rounded;
    final categoryName = category?.name ?? 'Unknown';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),

          // Category name + note preview + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        categoryName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (budgetName != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.tertiary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          budgetName!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.appColors.tertiary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (expense.note != null && expense.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    expense.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('h:mm a').format(expense.time),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    if (expense.receiptImagePath != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 14,
                        color: context.appColors.secondary,
                        semanticLabel: 'Receipt attached',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Amount + info icon
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(expense.amount, decimalDigits: 0),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (onInfoTap != null) ...[
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onInfoTap,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
