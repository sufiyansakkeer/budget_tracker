import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/info_content.dart';
import '../../domain/entities/monthly_spending_bucket.dart';
import 'chart_card.dart';
import '../../../../core/widgets/chart_reveal.dart';

/// Spending grouped into weeks (month views) or months (year view).
class BarChartCard extends StatelessWidget {
  final List<SpendingBucket> buckets;
  final String currency;

  /// "week" or "month" – used in the title and copy.
  final String unit;

  const BarChartCard({
    super.key,
    required this.buckets,
    required this.currency,
    this.unit = 'week',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final active = buckets.where((b) => b.amount > 0).toList();
    String money(double v) =>
        CurrencyFormatter.format(v, code: currency, decimalDigits: 0);

    SpendingBucket? top;
    for (final b in buckets) {
      if (top == null || b.amount > top.amount) top = b;
    }
    final title = 'Spending by $unit';

    return ChartCard(
      title: title,
      caption: top != null && top.amount > 0
          ? 'Highest $unit: ${_label(top)} · ${money(top.amount)}'
          : null,
      info: InfoContent(
        title: title,
        whatIsThis:
            "Your active budget's spending in the selected period, grouped "
            'by $unit, so you can see which ${unit}s were heavier.',
        howIsItCalculated:
            'Expenses are added up per $unit based on their recorded date. '
            '${unit == 'week' ? 'Weeks start on Monday.' : ''}',
      ),
      child: active.length < 2
          ? ChartPlaceholder(
              icon: Icons.bar_chart_rounded,
              message: active.isEmpty
                  ? 'No spending in this period yet'
                  : 'Bars appear once more than one $unit has spending.',
            )
          : SizedBox(
              height: AppSizes.chartHeight,
              child: Semantics(
                label: 'Bar chart of spending by $unit, ${buckets.length} bars',
                // Bars grow upward once on first appearance; later dataset
                // changes use fl_chart's own tween (disabled while revealing
                // so the two never fight).
                child: ChartReveal(
                  builder: (context, reveal, revealing) => BarChart(
                    duration: revealing
                        ? Duration.zero
                        : AppMotion.respectReducedMotion(
                            context,
                            AppMotion.emphasized,
                          ),
                    curve: AppMotion.value,
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _maxY(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => colorScheme.inverseSurface,
                          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                            money(rod.toY),
                            theme.textTheme.labelLarge!.copyWith(
                              color: colorScheme.onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: colorScheme.outlineVariant,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                NumberFormat.compact().format(value),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= buckets.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Text(
                                  _label(buckets[index]),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        for (var i = 0; i < buckets.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: buckets[i].amount * reveal,
                                color: identical(buckets[i], top)
                                    ? colorScheme.primary
                                    : colorScheme.primary.withValues(
                                        alpha: 0.55,
                                      ),
                                width: buckets.length > 8 ? 12 : 20,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppSpacing.radiusXs),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// Friendly bucket labels: "1 Sep" for weeks, "Sep" for months.
  String _label(SpendingBucket bucket) {
    if (unit == 'month') return DateFormat('MMM').format(bucket.startDate);
    return DateFormat('d MMM').format(bucket.startDate);
  }

  double _maxY() {
    var max = 0.0;
    for (final bucket in buckets) {
      if (bucket.amount > max) max = bucket.amount;
    }
    return max <= 0 ? 1 : max * 1.15;
  }
}
