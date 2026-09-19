import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/budget_list_summary_entity.dart';

/// Displays the combined remaining amount across all budgets running today.
///
/// A reference figure only: budgets themselves are never merged.
class BudgetListSummaryCard extends StatelessWidget {
  final BudgetListSummaryEntity summary;

  const BudgetListSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (summary.activeBudgetCount == 0) return const SizedBox.shrink();

    final s = CurrencyFormatter.symbolFor(summary.currency);
    final count = summary.activeBudgetCount;

    return AppCard(
      color: theme.colorScheme.surfaceContainer,
      showBorder: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smd,
      ),
      child: Row(
        children: [
          IconTile(
            icon: Icons.account_balance_wallet_rounded,
            color: theme.colorScheme.primary,
            size: AppSizes.avatarSm,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Total remaining',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InfoIcon(
                      content: InfoContent(
                        title: 'Total remaining',
                        whatIsThis:
                            'A reference number: the remaining amount of '
                            'every budget running today, added together. '
                            'It does not merge your budgets.',
                        howIsItCalculated:
                            'For each budget running today:\n'
                            '  Remaining = Budget amount − Total spent\n\n'
                            'Then those amounts are added together.',
                        example:
                            'Budget A: ${s}10,000 − ${s}5,000 = ${s}5,000\n'
                            'Budget B: ${s}8,000 − ${s}5,000 = ${s}3,000\n\n'
                            'Total remaining: ${s}8,000',
                        additionalNotes:
                            '• Includes budgets that are not archived and '
                            'whose period includes today\n'
                            "• Each budget keeps its own amount, period, "
                            "expenses and Today's Safe Spending; safe "
                            'spending is never added together\n'
                            "• Shown in the first active budget's currency\n"
                            '• Can be negative if a budget is overspent',
                      ),
                    ),
                  ],
                ),
                Text(
                  'Across $count ${count == 1 ? 'budget' : 'budgets'} running today',
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
              amount: summary.totalRemaining,
              currency: summary.currency,
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
