import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/report_overview.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/spending_trend.dart';

/// The report's headline: total spent in the period, how that compares with
/// the stretch just before it, and the averages behind it.
class ReportSummaryCard extends StatelessWidget {
  final ReportOverview overview;
  final SpendingTrend trend;
  final ReportRange range;
  final String currency;

  const ReportSummaryCard({
    super.key,
    required this.overview,
    required this.trend,
    required this.range,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final s = CurrencyFormatter.symbolFor(currency);

    final growthPct = (trend.growthRate * 100).abs();
    final hasComparison = trend.growthRate != 0 && growthPct >= 1;
    final decreased = trend.growthRate < 0;
    final txns = overview.totalTransactions;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.mlg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Total spent',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    InfoIcon(
                      content: InfoContent(
                        title: 'Total spent',
                        whatIsThis:
                            "The total of your active budget's expenses in "
                            'the selected report period.',
                        howIsItCalculated:
                            'All expenses in the active budget whose date '
                            'falls within the selected period (and match any '
                            'filters) are added together.\n\n'
                            'Per day = Total ÷ Days in the period.\n'
                            'The comparison looks at the same number of days '
                            'immediately before the period.',
                        example:
                            'Period: 1 Aug – 25 Aug (25 days)\n'
                            'Total: ${s}9,000 · Per day: ${s}360\n'
                            'Previous 25 days: ${s}10,000 → 10% less',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$txns ${txns == 1 ? 'expense' : 'expenses'}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedAmount(
            amount: overview.totalSpending,
            currency: currency,
            style: theme.textTheme.displaySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (hasComparison)
            Row(
              children: [
                Icon(
                  decreased
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  size: AppSizes.iconSm,
                  color: decreased ? colors.success : colors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${growthPct.toStringAsFixed(0)}% ${decreased ? 'less' : 'more'} '
                    'than the previous ${range.dayCount} days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: decreased ? colors.success : colors.warning,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Text(
              trend.growthRate == 0 && overview.totalSpending > 0
                  ? 'No comparable spending in the previous '
                        '${range.dayCount} days'
                  : 'About the same as the previous ${range.dayCount} days',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Per day',
                  amount: overview.averageDailySpending,
                  currency: currency,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Per expense',
                  amount: overview.averageTransactionAmount,
                  currency: currency,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Largest',
                  amount: overview.highestExpense,
                  currency: currency,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;

  const _Metric({
    required this.label,
    required this.amount,
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
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        AnimatedAmount(
          amount: amount,
          currency: currency,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
