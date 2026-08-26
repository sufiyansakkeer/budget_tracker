import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/budget_list_summary_entity.dart';

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
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Total Remaining',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              InfoIcon(
                content: InfoContent(
                  title: 'Combined Remaining',
                  whatIsThis:
                      'The total remaining budget across all your '
                      'active budgets.',
                  howIsItCalculated:
                      'For each active budget:\n'
                      '  Remaining = Budget amount − Spent amount\n\n'
                      'Then all active budget remainders are added '
                      'together.',
                  example:
                      'Budget A: ₹10,000 − ₹5,000 = ₹5,000 remaining\n'
                      'Budget B: ₹8,000 − ₹5,000 = ₹3,000 remaining\n\n'
                      'Combined remaining: ₹8,000',
                  additionalNotes:
                      '• Only active (non-archived) budgets are included\n'
                      '• Each budget has its own amount, date range, '
                      'and spending\n'
                      '• Can be negative if overspending on a budget',
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
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Across ${summary.activeBudgetCount} active budget${summary.activeBudgetCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
