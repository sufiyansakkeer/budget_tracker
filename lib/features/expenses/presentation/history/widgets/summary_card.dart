import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../domain/entities/expense_history_summary.dart';
import '../../../../../core/widgets/animated_amount.dart';

/// Compact summary strip for the currently visible results.
///
/// One row: total amount (primary), expense count and average (secondary).
/// It scrolls with the list so it never crowds the results.
class SummaryCard extends StatelessWidget {
  final ExpenseHistorySummary summary;
  final String? currency;

  /// Optional caption shown under the title, e.g. "Across 3 budgets".
  final String? caption;

  const SummaryCard({
    super.key,
    required this.summary,
    this.currency,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String money(double v) =>
        CurrencyFormatter.format(v, code: currency, decimalDigits: 0);
    final count = summary.totalExpenses;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smd,
      ),
      color: theme.colorScheme.surfaceContainer,
      showBorder: false,
      borderRadius: AppSpacing.borderRadiusMd,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  caption ??
                      '$count ${count == 1 ? 'expense' : 'expenses'}'
                          '${count > 0 ? ' · avg ${money(summary.averageExpense)}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: AnimatedAmount(
              amount: summary.totalAmount,
              currency: currency,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
