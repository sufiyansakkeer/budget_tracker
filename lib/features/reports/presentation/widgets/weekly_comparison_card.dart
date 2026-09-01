import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/currency/currency_formatter.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/weekly_comparison.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// Compares the current week's spending with the previous week.
class WeeklyComparisonCard extends StatelessWidget {
  final WeeklyComparison comparison;
  final String currency;

  const WeeklyComparisonCard({
    super.key,
    required this.comparison,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDecrease = comparison.isDecrease;
    final color = isDecrease ? context.appColors.success : context.appColors.error;
    final icon = isDecrease ? Icons.trending_down : Icons.trending_up;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(
          color: theme.colorScheme.surfaceContainerHighest,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Week-over-Week',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InfoIcon(
                content: InfoContent(
                  title: 'Weekly Comparison',
                  whatIsThis:
                      'Compares your spending between the current '
                      'week and the previous week.',
                  howIsItCalculated:
                      'Current week: Expenses from Monday to today\n'
                      'Previous week: Expenses from the Monday '
                      'before that\n\n'
                      'Difference = Current − Previous\n'
                      'Percentage change = Difference ÷ '
                      'Previous × 100',
                  example:
                      'Previous week: ₹8,000\n'
                      'Current week: ₹6,800\n\n'
                      'Difference: −₹1,200\n'
                      'Change: −15% (spending decreased)',
                  additionalNotes:
                      '• Green means you spent less than last week\n'
                      '• Red means you spent more than last week\n'
                      '• Weeks run Monday through Sunday',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _WeekColumn(
                  label: 'Current Week',
                  value: comparison.currentWeekSpending,
                  currency: currency,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _WeekColumn(
                  label: 'Previous Week',
                  value: comparison.previousWeekSpending,
                  currency: currency,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppSpacing.borderRadiusSm,
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    comparison.difference == 0
                        ? 'No change from last week.'
                        : '${comparison.difference.abs() > 0 ? (comparison.difference > 0 ? 'Spent' : 'Saved') : ''} '
                              '${NumberFormat.compact().format(comparison.difference.abs())} '
                              '(${comparison.percentageChange >= 0 ? '+' : ''}'
                              '${(comparison.percentageChange * 100).toStringAsFixed(0)}%)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekColumn extends StatelessWidget {
  final String label;
  final double value;
  final String currency;

  const _WeekColumn({
    required this.label,
    required this.value,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          CurrencyFormatter.format(value, code: currency, decimalDigits: 0),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
