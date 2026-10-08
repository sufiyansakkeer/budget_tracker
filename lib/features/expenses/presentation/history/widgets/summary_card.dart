import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_money.dart';
import '../../../domain/entities/expense_history_summary.dart';

/// What the visible expenses add up to, as type rather than a card: a
/// "Summary" label, then one line with the total and, quietly, how many
/// and the average.
///
/// A combined view of budgets in different currencies gets one total per
/// currency and no average, since adding them up would mean nothing.
class SummaryCard extends StatelessWidget {
  final ExpenseHistorySummary summary;
  final String? currency;

  /// Replaces the count line, e.g. "Across 3 budgets · 24 expenses".
  final String? caption;

  /// Totals per currency when the view mixes currencies.
  final Map<String, ExpenseHistorySummary> byCurrency;

  const SummaryCard({
    super.key,
    required this.summary,
    this.currency,
    this.caption,
    this.byCurrency = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = context.appTypography;
    final count = summary.totalExpenses;
    final mixed = byCurrency.length > 1;
    final line =
        caption ??
        '$count ${count == 1 ? 'expense' : 'expenses'}'
            '${count > 0 && !mixed ? ' · avg ${AppMoney.format(summary.averageExpense, currency: currency)}' : ''}';

    final totals = mixed
        ? Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final entry in byCurrency.entries)
                AppMoney(
                  amount: entry.value.totalAmount,
                  currency: entry.key,
                  role: MoneyRole.title,
                ),
            ],
          )
        : AppMoney(
            amount: summary.totalAmount,
            currency: currency,
            role: MoneyRole.title,
          );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: typography.eyebrow.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          // The total and the count read as one line, wrapping only when
          // the text is too large to share it.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              totals,
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
