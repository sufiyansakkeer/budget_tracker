import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/info_content.dart';
import '../../domain/entities/weekly_comparison.dart';
import 'chart_card.dart';

/// Compares this week's spending with the stretch just before it.
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
    final colors = context.appColors;
    final s = CurrencyFormatter.symbolFor(currency);
    String money(double v) =>
        CurrencyFormatter.format(v, code: currency, decimalDigits: 0);

    final diff = comparison.difference;
    final noChange = diff.abs() < 0.5;
    final decreased = comparison.isDecrease;
    final hasPrevious = comparison.previousWeekSpending > 0;
    // percentageChange is already a percentage (e.g. -15 for -15%).
    final pct = comparison.percentageChange.abs();

    final Color color;
    final IconData icon;
    final String verdict;
    if (!hasPrevious) {
      color = theme.colorScheme.onSurfaceVariant;
      icon = Icons.info_outline_rounded;
      verdict = 'Nothing was spent in the previous week to compare with.';
    } else if (noChange) {
      color = theme.colorScheme.onSurfaceVariant;
      icon = Icons.drag_handle_rounded;
      verdict = 'Same as the previous week.';
    } else if (decreased) {
      color = colors.success;
      icon = Icons.trending_down_rounded;
      verdict =
          '${money(diff.abs())} less than the previous week '
          '(${pct.toStringAsFixed(0)}% down)';
    } else {
      color = colors.warning;
      icon = Icons.trending_up_rounded;
      verdict =
          '${money(diff.abs())} more than the previous week '
          '(${pct.toStringAsFixed(0)}% up)';
    }

    final maxValue = [
      comparison.currentWeekSpending,
      comparison.previousWeekSpending,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return ChartCard(
      title: 'This week vs last week',
      info: InfoContent(
        title: 'This week vs last week',
        whatIsThis:
            "Compares your active budget's spending in the selected week "
            'with the days just before it.',
        howIsItCalculated:
            'This Week: Monday to today, compared with the same number of '
            'days immediately before Monday.\n'
            'Last Week: Monday to Sunday of last week, compared with the '
            'full week before it.\n\n'
            'Difference = Current − Previous\n'
            'Change = Difference ÷ Previous',
        example:
            'Previous week: ${s}8,000\n'
            'Current week: ${s}6,800\n'
            'Difference: −${s}1,200 (15% down)',
        additionalNotes:
            '• Weeks run Monday through Sunday\n'
            '• Only shown for the This Week and Last Week periods',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bar(
            label: 'This week',
            amount: comparison.currentWeekSpending,
            fraction: comparison.currentWeekSpending / maxValue,
            color: theme.colorScheme.primary,
            currency: currency,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Bar(
            label: 'Previous week',
            amount: comparison.previousWeekSpending,
            fraction: comparison.previousWeekSpending / maxValue,
            color: theme.colorScheme.outlineVariant,
            currency: currency,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(icon, size: AppSizes.iconSm + 2, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  verdict,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double amount;
  final double fraction;
  final Color color;
  final String currency;

  const _Bar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AnimatedAmount(
              amount: amount,
              currency: currency,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppSpacing.borderRadiusFull,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fraction.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: AppSizes.progressMd,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
        ),
      ],
    );
  }
}
