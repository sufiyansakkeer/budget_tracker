import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_money.dart';
import '../../domain/entities/time_analytics.dart';
import 'report_copy.dart';

/// Spending by day of the week: seven columns, Monday to Sunday, with the
/// heaviest day in the accent colour, then which day leads and how much of
/// the spending fell on weekends.
class WeekdayRhythm extends StatelessWidget {
  final TimeAnalytics analytics;
  final String currency;

  const WeekdayRhythm({
    super.key,
    required this.analytics,
    required this.currency,
  });

  /// Whether there is a rhythm to show: spending on at least two weekdays.
  static bool hasRhythm(TimeAnalytics analytics) =>
      analytics.weekdayBreakdown.where((d) => d.amount > 0).length >= 2;

  static const double _barArea = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final byDay = {for (final d in analytics.weekdayBreakdown) d.weekday: d};
    var max = 0.0;
    for (final d in analytics.weekdayBreakdown) {
      if (d.amount > max) max = d.amount;
    }
    final lead = analytics.highestSpendingWeekday;
    final total = analytics.weekdaySpending + analytics.weekendSpending;
    final weekendShare = total <= 0
        ? 0
        : (analytics.weekendSpending / total * 100).round();
    final leadLine = lead == null
        ? null
        : 'Most on ${ReportCopy.weekdays[lead - 1]}s';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: [
            for (var day = 1; day <= 7; day++)
              '${ReportCopy.weekdays[day - 1]} '
                  '${AppMoney.format(byDay[day]?.amount ?? 0, currency: currency)}',
          ].join(', '),
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: _barArea,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: 0.56,
                            heightFactor: max <= 0
                                ? 0
                                : ((byDay[day]?.amount ?? 0) / max).clamp(
                                    0.02,
                                    1.0,
                                  ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: day == lead
                                    ? scheme.primary
                                    : scheme.primary.withValues(alpha: 0.3),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppSpacing.xs),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        ReportCopy.shortWeekday(day),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: day == lead
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: day == lead ? FontWeight.w700 : null,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          [?leadLine, 'weekends are $weekendShare% of spending'].join(' · '),
          style: muted,
        ),
      ],
    );
  }
}
