import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/budget_list_summary_entity.dart';

/// The remaining amount across all budgets running today, one figure per
/// currency, as a quiet footer under the list.
///
/// A reference figure only: budgets themselves are never merged.
class BudgetListSummaryCard extends StatelessWidget {
  final BudgetListSummaryEntity summary;

  const BudgetListSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = summary.remainingByCurrency;
    if (summary.activeBudgetCount == 0 || totals.isEmpty) {
      return const SizedBox.shrink();
    }

    final s = CurrencyFormatter.symbolFor(totals.keys.first);
    final count = summary.activeBudgetCount;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // A quiet footer, not a card: the figure is for reference and must
    // never look like a pooled budget.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: theme.colorScheme.outlineVariant),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Flexible(
              child: Text(
                'Total remaining',
                style: context.appTypography.eyebrow.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InfoIcon(content: _info(s)),
          ],
        ),
        // One figure per currency: different currencies are never added.
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          children: [
            for (final MapEntry(key: code, value: amount) in totals.entries)
              AppMoney(amount: amount, currency: code, role: MoneyRole.title),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Across $count ${count == 1 ? 'budget' : 'budgets'} running today',
          style: muted,
        ),
      ],
    );
  }

  static InfoContent _info(String s) => InfoContent(
    title: 'Total remaining',
    whatIsThis:
        'A reference number: the remaining amount of every budget running '
        'today, added together. It does not merge your budgets.',
    howIsItCalculated:
        'For each budget running today:\n'
        '  Remaining = Budget amount − Total spent\n\n'
        'Then those amounts are added together.',
    example:
        'Budget A: ${s}10,000 − ${s}5,000 = ${s}5,000\n'
        'Budget B: ${s}8,000 − ${s}5,000 = ${s}3,000\n\n'
        'Total remaining: ${s}8,000',
    additionalNotes:
        '• Includes budgets that are not archived and whose period includes '
        'today\n'
        "• Each budget keeps its own amount, period, expenses and Today's "
        'Safe Spending; safe spending is never added together\n'
        '• Budgets in different currencies get separate totals; amounts are '
        'never converted\n'
        '• Can be negative if a budget is overspent',
  );
}
