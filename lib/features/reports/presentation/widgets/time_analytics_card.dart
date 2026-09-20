import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_content.dart';
import '../../domain/entities/daily_spending_point.dart';
import '../../domain/entities/spending_trend.dart';
import '../../domain/entities/time_analytics.dart';
import 'chart_card.dart';
import '../../../../core/constants/app_motion.dart';

/// "Patterns": when spending happens. Weekday vs weekend split, the day of
/// the week you spend most on, and how even your daily spending is.
class TimeAnalyticsCard extends StatelessWidget {
  final TimeAnalytics analytics;
  final SpendingTrend trend;
  final List<DailySpendingPoint> dailySpending;
  final String currency;

  const TimeAnalyticsCard({
    super.key,
    required this.analytics,
    required this.trend,
    required this.dailySpending,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final total = analytics.weekdaySpending + analytics.weekendSpending;
    final hasData = total > 0;
    final weekdayShare = hasData ? analytics.weekdaySpending / total : 0.0;
    String money(double v) =>
        CurrencyFormatter.format(v, code: currency, decimalDigits: 0);

    final busiest = analytics.highestSpendingWeekday;
    final busiestName = busiest == null ? null : _weekdayName(busiest);
    final consistency = (trend.consistencyScore * 100).clamp(0, 100).round();
    final activeDays = dailySpending.where((p) => p.amount > 0).length;

    double? peakAmount;
    if (analytics.mostExpensiveDay != null) {
      for (final p in dailySpending) {
        if (_sameDay(p.date, analytics.mostExpensiveDay!)) {
          peakAmount = p.amount;
          break;
        }
      }
    }

    return ChartCard(
      title: 'Patterns',
      caption: busiestName == null
          ? null
          : 'You spend the most on ${busiestName}s',
      info: const InfoContent(
        title: 'Patterns',
        whatIsThis:
            "When your active budget's spending happens in the selected "
            'period: weekdays versus weekends, the day of the week with the '
            'highest total, and how even your daily spending is.',
        howIsItCalculated:
            'Weekdays vs weekends: total spent Monday–Friday compared with '
            'Saturday–Sunday.\n'
            'Busiest day: the day of the week with the highest total across '
            'the period (a total, not an average).\n'
            'Consistency: how even your daily totals are, from 0% (very '
            'uneven) to 100% (the same every day).',
      ),
      child: !hasData
          ? const ChartPlaceholder(
              icon: Icons.calendar_view_week_rounded,
              message: 'Patterns appear once there is spending in this period',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekday / weekend split bar. The split animates when the
                // period changes so the proportion shifts rather than jumps.
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: weekdayShare),
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.emphasized,
                  ),
                  curve: AppMotion.value,
                  builder: (context, weekday, _) {
                    final weekend = 1 - weekday;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Weekdays · ${(weekday * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                            Text(
                              'Weekends · ${(weekend * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Semantics(
                          label:
                              'Weekdays ${money(analytics.weekdaySpending)}, '
                              'weekends ${money(analytics.weekendSpending)}',
                          child: ExcludeSemantics(
                            child: ClipRRect(
                              borderRadius: AppSpacing.borderRadiusFull,
                              child: SizedBox(
                                height: AppSizes.progressLg,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: (weekday * 1000).round().clamp(
                                        1,
                                        1000,
                                      ),
                                      child: ColoredBox(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      flex: (weekend * 1000).round().clamp(
                                        1,
                                        1000,
                                      ),
                                      child: ColoredBox(color: colors.tertiary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        money(analytics.weekdaySpending),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      money(analytics.weekendSpending),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _Fact(
                        icon: Icons.event_rounded,
                        label: 'Biggest day',
                        value: analytics.mostExpensiveDay == null
                            ? '—'
                            : DateFormat(
                                'EEE d MMM',
                              ).format(analytics.mostExpensiveDay!),
                        caption: peakAmount == null ? null : money(peakAmount),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _Fact(
                        icon: Icons.balance_rounded,
                        label: 'Consistency',
                        value: activeDays < 3 ? '—' : '$consistency%',
                        caption: activeDays < 3
                            ? 'Needs 3+ days'
                            : consistency >= 60
                            ? 'Fairly even'
                            : 'Varies a lot',
                        progress: activeDays < 3 ? null : consistency / 100,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayName(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][(weekday - 1).clamp(0, 6)];
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final double? progress;

  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: AppSizes.iconSm,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AppProgress(
              value: progress!,
              height: AppSizes.progressThin,
              color: theme.colorScheme.primary,
            ),
          ],
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
