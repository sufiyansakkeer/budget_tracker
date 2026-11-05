import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_money.dart';
import '../../domain/entities/time_analytics.dart';
import 'report_copy.dart';

/// Spending by day of the week: seven columns, Monday to Sunday, with the
/// heaviest day in the accent colour, then which day leads and, over whole
/// weeks, how much of the spending fell on weekends.
class WeekdayRhythm extends StatelessWidget {
  final TimeAnalytics analytics;
  final String currency;

  /// Whether the range is a whole number of weeks. Otherwise some weekdays
  /// occur more often than others, so the weekend share is left out.
  final bool wholeWeeks;

  const WeekdayRhythm({
    super.key,
    required this.analytics,
    required this.currency,
    required this.wholeWeeks,
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
    // The largest total per weekday in this range, not a habit: a 10-day
    // range has three weekdays twice.
    final leadLine = lead == null
        ? null
        : 'Most spent on ${ReportCopy.weekdays[lead - 1]}s in this period';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: CurrencyFormatter.forSpeech(
            [
              for (var day = 1; day <= 7; day++)
                '${ReportCopy.weekdays[day - 1]} '
                    '${AppMoney.format(byDay[day]?.amount ?? 0, currency: currency)}',
            ].join(', '),
          ),
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
                          child: (byDay[day]?.amount ?? 0) <= 0 || max <= 0
                              // A baseline tick, so a day with nothing
                              // reads as zero rather than missing.
                              ? FractionallySizedBox(
                                  key: ValueKey('rhythmZero_$day'),
                                  widthFactor: 0.56,
                                  child: SizedBox(
                                    height: AppSpacing.xxs,
                                    child: ColoredBox(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : FractionallySizedBox(
                                  widthFactor: 0.56,
                                  heightFactor: (byDay[day]!.amount / max)
                                      .clamp(0.04, 1.0),
                                  child: DecoratedBox(
                                    // Every bar meets the 3:1 non-text
                                    // floor; the lead is told apart by
                                    // hue and its bold label (UX-070).
                                    decoration: BoxDecoration(
                                      color: day == lead
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
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
          [
            ?leadLine,
            if (wholeWeeks) 'weekends are $weekendShare% of spending',
          ].join(' · '),
          style: muted,
        ),
      ],
    );
  }
}
