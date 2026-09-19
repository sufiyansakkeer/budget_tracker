import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/budget_list_summary_entity.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// Displays the combined remaining amount across all active budgets.
class BudgetListSummaryCard extends StatelessWidget {
  final BudgetListSummaryEntity summary;

  const BudgetListSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (summary.activeBudgetCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.appColors.secondary.withValues(alpha: 0.1),
            context.appColors.secondary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(
          color: context.appColors.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: context.appColors.secondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Total Remaining',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.appColors.secondary,
                ),
              ),
              const Spacer(),
              InfoIcon(
                content: InfoContent(
                  title: 'Total Remaining',
                  whatIsThis:
                      'An overview number: the Remaining Budget of every '
                      'budget that is running today, added together. It is '
                      'for reference only and does not merge your budgets.',
                  howIsItCalculated:
                      'For each budget running today:\n'
                      '  Remaining Budget = Budget amount − Total spent\n\n'
                      'Then those amounts are added together.',
                  example:
                      'Budget A: ₹10,000 − ₹5,000 = ₹5,000 remaining\n'
                      'Budget B: ₹8,000 − ₹5,000 = ₹3,000 remaining\n\n'
                      'Total Remaining: ₹8,000',
                  additionalNotes:
                      '• Includes budgets that are not archived and whose '
                      'period includes today\n'
                      '• Each budget keeps its own amount, period, expenses '
                      'and Today\'s Safe Spending. Safe spending is never '
                      'added together\n'
                      '• Amounts are shown in the first active budget\'s '
                      'currency\n'
                      '• Can be negative if a budget is overspent',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            CurrencyFormatter.format(
              summary.totalRemaining,
              code: summary.currency,
              decimalDigits: 0,
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.appColors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Across ${summary.activeBudgetCount} budget${summary.activeBudgetCount == 1 ? '' : 's'} running today',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
