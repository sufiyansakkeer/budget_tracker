import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/spending_trend.dart';

/// Displays spending trend metrics: averages, growth, and consistency.
class TrendCard extends StatelessWidget {
  final SpendingTrend trend;
  final String currency;

  const TrendCard({super.key, required this.trend, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final growthColor = trend.growthRate <= 0
        ? AppColors.safeGreen
        : AppColors.dangerRed;
    final growthIcon = trend.growthRate <= 0
        ? Icons.trending_down
        : Icons.trending_up;
    final consistencyPct = (trend.consistencyScore * 100).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spending Trends',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: growthColor.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(growthIcon, size: 16, color: growthColor),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${trend.growthRate >= 0 ? '+' : ''}${(trend.growthRate * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: growthColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Averages
          _AverageRow(
            label: 'Daily average',
            value: trend.dailyAverage,
            currency: currency,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AverageRow(
            label: 'Weekly average',
            value: trend.weeklyAverage,
            currency: currency,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AverageRow(
            label: 'Monthly average',
            value: trend.monthlyAverage,
            currency: currency,
          ),
          const SizedBox(height: AppSpacing.md),

          // Consistency
          Row(
            children: [
              Text(
                'Consistency',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppSpacing.borderRadiusSm,
                  child: LinearProgressIndicator(
                    value: trend.consistencyScore.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      trend.consistencyScore >= 0.6
                          ? AppColors.safeGreen
                          : AppColors.warningOrange,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${consistencyPct.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            trend.isImproving
                ? 'Your spending trend has improved in the recent period.'
                : 'Spending has increased in the recent period.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: trend.isImproving
                  ? AppColors.safeGreen
                  : AppColors.warningOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _AverageRow extends StatelessWidget {
  final String label;
  final double value;
  final String currency;

  const _AverageRow({
    required this.label,
    required this.value,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Text(
          NumberFormat.currency(
            symbol: currency,
            decimalDigits: 0,
          ).format(value),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
