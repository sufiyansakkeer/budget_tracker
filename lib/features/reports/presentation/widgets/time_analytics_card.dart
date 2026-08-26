import 'package:flutter/material.dart';
import '../../../../core/currency/currency_formatter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/time_analytics.dart';

/// Displays time-based analytics: most/least active days and weekend vs
/// weekday spending.
class TimeAnalyticsCard extends StatelessWidget {
  final TimeAnalytics analytics;
  final String currency;

  const TimeAnalyticsCard({
    super.key,
    required this.analytics,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mostExpensive = analytics.mostExpensiveDay;
    final mostActive = analytics.mostActiveDay;

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
                  'Time Analytics',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InfoIcon(
                content: InfoContent(
                  title: 'Time Analytics',
                  whatIsThis:
                      'Breakdown of your spending patterns by '
                      'calendar day and day of the week.',
                  howIsItCalculated:
                      'Most Expensive Day: Calendar day with the '
                      'highest total expenses.\n'
                      'Most Active Day: Day with the most '
                      'transactions.\n'
                      'Weekday vs Weekend: Sum of Mon–Fri vs '
                      'Sat–Sun expenses.',
                  example:
                      '23 Aug: ₹2,000 (highest)\n'
                      'Weekday total: ₹12,000\n'
                      'Weekend total: ₹3,000',
                  additionalNotes:
                      '• Expenses are grouped by their recorded date\n'
                      '• Most expensive day shows the highest '
                      'single-day total\n'
                      '• Highest spending weekday is the most '
                      'expensive day of the week on average',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _TimeMetric(
                  label: 'Most Expensive Day',
                  value: mostExpensive == null ? '—' : _fmt(mostExpensive),
                  icon: Icons.arrow_upward,
                  color: AppColors.dangerRed,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _TimeMetric(
                  label: 'Most Active Day',
                  value: mostActive == null ? '—' : _fmt(mostActive),
                  icon: Icons.local_fire_department,
                  color: AppColors.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _TimeMetric(
                  label: 'Weekday Spending',
                  value: CurrencyFormatter.format(
                    analytics.weekdaySpending,
                    code: currency,
                    decimalDigits: 0,
                  ),
                  icon: Icons.work,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _TimeMetric(
                  label: 'Weekend Spending',
                  value: CurrencyFormatter.format(
                    analytics.weekendSpending,
                    code: currency,
                    decimalDigits: 0,
                  ),
                  icon: Icons.weekend,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          if (analytics.highestSpendingWeekday != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Highest spending day: ${_weekdayName(analytics.highestSpendingWeekday!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}';

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }
}

class _TimeMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TimeMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
