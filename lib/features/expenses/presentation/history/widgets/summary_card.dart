import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../domain/entities/expense_history_summary.dart';
import '../../../../../core/theme/app_colors_extension.dart';

/// Summary card showing statistics for the currently visible results.
class SummaryCard extends StatelessWidget {
  final ExpenseHistorySummary summary;

  const SummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '', decimalDigits: 0);

    return AppCard(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.appColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: context.appColors.primary,
                  size: 18,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Summary',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _summaryItem(
                theme,
                label: 'Total Expenses',
                value: '${summary.totalExpenses}',
              ),
              _summaryItem(
                theme,
                label: 'Total Amount',
                value: currency.format(summary.totalAmount),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _summaryItem(
                theme,
                label: 'Average',
                value: currency.format(summary.averageExpense),
              ),
              _summaryItem(
                theme,
                label: 'Highest',
                value: currency.format(summary.highestExpense),
              ),
              _summaryItem(
                theme,
                label: 'Lowest',
                value: currency.format(summary.lowestExpense),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    ThemeData theme, {
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
