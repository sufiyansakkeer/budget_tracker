import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/currency/currency_formatter.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/daily_spending_point.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// Card containing a smooth daily-spending line chart.
class LineChartCard extends StatefulWidget {
  final List<DailySpendingPoint> points;
  final String currency;

  const LineChartCard({
    super.key,
    required this.points,
    required this.currency,
  });

  @override
  State<LineChartCard> createState() => _LineChartCardState();
}

class _LineChartCardState extends State<LineChartCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty =
        widget.points.isEmpty || widget.points.every((p) => p.amount <= 0);

    return _ChartCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Spending',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (empty)
            _EmptyChartLabel()
          else
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.surface,
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              CurrencyFormatter.format(
                                spot.y,
                                code: widget.currency,
                                decimalDigits: 0,
                              ),
                              TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    touchCallback: (event, response) {
                      if (response != null && response.lineBarSpots != null) {
                        final index = response.lineBarSpots!.first.x.toInt();
                        if (index != _touchedIndex) {
                          setState(() => _touchedIndex = index);
                        }
                      }
                    },
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.surfaceContainerHighest,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compact().format(value),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
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
                          if (index < 0 || index >= widget.points.length) {
                            return const SizedBox.shrink();
                          }
                          final date = widget.points[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
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
                        for (var i = 0; i < widget.points.length; i++)
                          FlSpot(i.toDouble(), widget.points[i].amount),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: context.appColors.secondary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: context.appColors.secondary.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _bottomInterval() {
    final count = widget.points.length;
    if (count <= 7) return 1;
    if (count <= 31) return 5;
    if (count <= 62) return 10;
    return 30;
  }
}

/// Container used to standardize chart card styling.
class _ChartCardContainer extends StatelessWidget {
  final Widget child;

  const _ChartCardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: child,
    );
  }
}

class _EmptyChartLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          'No spending data for this period',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
