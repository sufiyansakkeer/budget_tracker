import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/theme/app_colors_extension.dart';
import '../../../../../core/theme/contrast.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../widgets/category_visuals.dart';
import '../../../../../core/widgets/animated_amount.dart';
import '../../../../../core/widgets/pressable.dart';

/// A single expense row in the history list.
///
/// Hierarchy: category icon → title (note, or category when there is no
/// note) → supporting line (category · time · budget chip in combined mode)
/// → amount. Tapping opens the expense details.
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
    final colors = context.appColors;
    final color = category != null
        ? CategoryVisuals.adaptiveColor(context, category!.colorHex)
        : theme.colorScheme.onSurfaceVariant;
    final icon = category != null
        ? CategoryVisuals.iconFor(category!.icon)
        : Icons.category_rounded;
    final categoryName = category?.name ?? 'Uncategorised';
    final hasNote = expense.note != null && expense.note!.trim().isNotEmpty;
    final amount = CurrencyFormatter.format(
      expense.amount,
      code: currency,
      decimalDigits: 0,
    );
    final time = DateFormat('h:mm a').format(expense.time);

    return Semantics(
      button: onTap != null,
      label:
          '${hasNote ? expense.note : categoryName}, $categoryName, $amount, '
          '$time${budgetName != null ? ', budget $budgetName' : ''}'
          '${expense.receiptImagePath != null ? ', receipt attached' : ''}',
      onLongPressHint: onLongPress != null ? 'more actions' : null,
      // The actions must live on the node that advertises the button, or
      // "activate" from a screen reader has nothing to invoke.
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: Pressable(
        enabled: onTap != null || onLongPress != null,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.smd,
            ),
            child: Row(
              children: [
                IconTile(icon: icon, color: color),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasNote ? expense.note!.trim() : categoryName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          if (hasNote)
                            Flexible(
                              child: Text(
                                categoryName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Text(
                            hasNote ? ' · $time' : time,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                          ),
                          if (expense.receiptImagePath != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(
                              Icons.receipt_long_rounded,
                              size: AppSizes.iconXs,
                              color: theme.colorScheme.onSurfaceVariant,
                              semanticLabel: 'Receipt attached',
                            ),
                          ],
                          if (budgetName != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: _BudgetTag(
                                name: budgetName!,
                                color: colors.tertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AnimatedAmount(
                  amount: expense.amount,
                  currency: currency,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (onInfoTap != null)
                  IconButton(
                    onPressed: onInfoTap,
                    tooltip: 'Expense and budget details',
                    iconSize: AppSizes.iconSm + 2,
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetTag extends StatelessWidget {
  final String name;
  final Color color;

  const _BudgetTag({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppSpacing.borderRadiusXs,
      ),
      child: Text(
        name,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Contrast.ensureContrast(
            color,
            Color.alphaBlend(
              color.withValues(alpha: 0.12),
              theme.colorScheme.surface,
            ),
          ),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
