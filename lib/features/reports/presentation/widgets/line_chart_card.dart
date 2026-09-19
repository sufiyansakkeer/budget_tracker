import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/info_content.dart';
import '../../domain/entities/daily_spending_point.dart';
import 'chart_card.dart';

/// Daily spending over the period as a smooth line.
class LineChartCard extends StatelessWidget {
  final List<DailySpendingPoint> points;
  final String currency;

  const LineChartCard({
    super.key,
    required this.points,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeDays = points.where((p) => p.amount > 0).length;
    final total = points.fold<double>(0, (s, p) => s + p.amount);
    DailySpendingPoint? peak;
    for (final p in points) {
      if (peak == null || p.amount > peak.amount) peak = p;
    }
    String money(double v) =>
        CurrencyFormatter.format(v, code: currency, decimalDigits: 0);

    final String? caption;
    if (activeDays == 0 || total <= 0) {
      caption = null;
    } else if (peak != null && peak.amount > 0) {
      caption =
          'Highest day: ${DateFormat('EEE d MMM').format(peak.date)} · '
          '${money(peak.amount)}';
    } else {
      caption = null;
    }

    return ChartCard(
      title: 'Spending by day',
      caption: caption,
      info: InfoContent(
        title: 'Spending by day',
        whatIsThis:
            "Your active budget's total spending on each day of the "
            'selected period.',
        howIsItCalculated:
            'Expenses are grouped by their recorded date and added up per '
            'day. Days with no expenses show as zero.',
        additionalNotes: '• Tap or drag on the chart to see a day\'s total',
      ),
      child: activeDays == 0
          ? const ChartPlaceholder(message: 'No spending in this period yet')
          : activeDays < 2
          ? ChartPlaceholder(
              icon: Icons.timeline_rounded,
              message:
                  'Spending recorded on one day so far. A trend line '
                  'appears once you spend on more days.',
            )
          : SizedBox(
              height: AppSizes.chartHeight,
              child: Semantics(
                label:
                    'Line chart of daily spending, ${points.length} days, '
                    'total ${money(total)}',
                child: LineChart(
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.emphasized,
                  ),
                  curve: AppMotion.value,
                  LineChartData(
                    minY: 0,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => colorScheme.inverseSurface,
                        getTooltipItems: (spots) => [
                          for (final spot in spots)
                            LineTooltipItem(
                              '${DateFormat('d MMM').format(points[spot.x.toInt()].date)}\n',
                              theme.textTheme.labelSmall!.copyWith(
                                color: colorScheme.onInverseSurface,
                              ),
                              children: [
                                TextSpan(
                                  text: money(spot.y),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onInverseSurface,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
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
                          interval: _bottomInterval(),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: Text(
                                DateFormat(
                                  points.length <= 7 ? 'E' : 'd MMM',
                                ).format(points[index].date),
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
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].amount),
                        ],
                        isCurved: true,
                        curveSmoothness: 0.3,
                        preventCurveOverShooting: true,
                        color: colorScheme.primary,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: points.length <= 14,
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: colorScheme.primary,
                                strokeWidth: 0,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.2),
                              colorScheme.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  double _bottomInterval() {
    final count = points.length;
    if (count <= 7) return 1;
    if (count <= 31) return 7;
    if (count <= 62) return 14;
    return 30;
  }
}
