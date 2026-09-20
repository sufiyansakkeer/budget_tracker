import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../domain/entities/recent_expense_entity.dart';

/// A scannable row for a recent expense: category icon, title, time, amount.
class RecentExpenseTile extends StatelessWidget {
  final RecentExpenseEntity expense;
  final String currency;
  final VoidCallback? onTap;

  const RecentExpenseTile({
    super.key,
    required this.expense,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = CategoryVisuals.adaptiveColor(
      context,
      expense.categoryColorHex,
    );
    final hasNote = expense.note != null && expense.note!.trim().isNotEmpty;
    final amount = CurrencyFormatter.format(
      expense.amount,
      code: currency,
      decimalDigits: 0,
    );
    final when = _formatTime(expense.date);

    return Semantics(
      button: onTap != null,
      label:
          '${hasNote ? expense.note : expense.categoryName}, '
          '${expense.categoryName}, $amount, $when',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.smd,
            ),
            child: Row(
              children: [
                IconTile(
                  icon: CategoryVisuals.iconFor(expense.categoryIcon),
                  color: color,
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasNote ? expense.note! : expense.categoryName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        hasNote ? '${expense.categoryName} · $when' : when,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Text(
                  '−$amount',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final time = DateFormat.jm().format(date);
    if (day == today) return 'Today, $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    return DateFormat('d MMM').format(date);
  }
}
