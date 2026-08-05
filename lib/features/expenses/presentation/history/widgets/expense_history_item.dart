import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../widgets/category_visuals.dart';

/// Animated tile for a single expense in the history list.
///
/// Shows category icon/color, name, amount, date, time, note preview, and a
/// receipt indicator. Tapping it opens the expense details.
class ExpenseHistoryItem extends StatelessWidget {
  final ExpenseEntity expense;
  final ExpenseCategory? category;
  final VoidCallback? onTap;

  const ExpenseHistoryItem({
    super.key,
    required this.expense,
    this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category != null
        ? CategoryVisuals.colorFor(category!.colorHex)
        : Colors.grey;
    final icon = category != null
        ? CategoryVisuals.iconFor(category!.icon)
        : Icons.help_outline;
    final categoryName = category?.name ?? 'Unknown';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Category icon
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),

              // Category name + note preview + tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (expense.note != null && expense.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        expense.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
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
                            Icons.receipt_long,
                            size: 14,
                            color: AppColors.primary,
                            semanticLabel: 'Receipt attached',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Amount
              Text(
                NumberFormat.currency(
                  symbol: '',
                  decimalDigits: 0,
                ).format(expense.amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
