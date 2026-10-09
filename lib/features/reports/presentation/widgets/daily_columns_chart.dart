import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/chart_reveal.dart';
import '../../domain/entities/daily_spending_point.dart';

/// One column per day with a dashed line at the daily average. Tapping a
/// column names the day and its total under the chart (rather than in a
/// floating tooltip), so it reads with large text and screen readers too.
///
/// Columns are real totals: nothing is smoothed or interpolated.
class DailyColumnsChart extends StatefulWidget {
  final List<DailySpendingPoint> points;
  final double average;
  final String currency;

  const DailyColumnsChart({
    super.key,
    required this.points,
    required this.average,
    required this.currency,
  });

  @override
  State<DailyColumnsChart> createState() => _DailyColumnsChartState();
}

class _DailyColumnsChartState extends State<DailyColumnsChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant DailyColumnsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.points.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final points = widget.points;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final day = DateFormat('EEE d MMM');
    String money(double v) => AppMoney.format(v, currency: widget.currency);

    DailySpendingPoint? top;
    for (final p in points) {
      if (top == null || p.amount > top.amount) top = p;
    }
    final maxY = math.max(top?.amount ?? 0, widget.average);
    final selected = _selected == null ? null : points[_selected!];
    final n = points.length;
    final barWidth = n <= 7
        ? 18.0
        : n <= 14
        ? 12.0
        : n <= 31
        ? 6.0
        : 4.0;
    // Label every few days so the axis never crowds.
    final step = math.max(1, (n / 6).ceil());

    final caption = selected != null
        ? '${day.format(selected.date)} · ${money(selected.amount)}'
        : top == null || top.amount <= 0
        ? 'No spending in this period yet'
        : 'Highest ${day.format(top.date)} · ${money(top.amount)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              'Daily spending over $n ${n == 1 ? 'day' : 'days'}, average '
              '${money(widget.average)} a day'
              '${top != null && top.amount > 0 ? ', highest ${day.format(top.date)}, ${money(top.amount)}' : ''}',
          excludeSemantics: true,
          child: SizedBox(
            height: AppSizes.chartHeight,
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
                  alignment: BarChartAlignment.spaceBetween,
                  maxY: maxY <= 0 ? 1 : maxY * 1.15,
                  barTouchData: BarTouchData(
                    handleBuiltInTouches: false,
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final index = response?.spot?.touchedBarGroupIndex;
                      setState(
                        () => _selected = index == _selected ? null : index,
                      );
                    },
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (widget.average > 0)
                        HorizontalLine(
                          y: widget.average,
                          color: scheme.onSurfaceVariant,
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            labelResolver: (_) => 'avg',
                          ),
                        ),
                    ],
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == 0) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            NumberFormat.compact().format(value),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= n || i % step != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              n <= 7
                                  ? DateFormat('E').format(points[i].date)
                                  : '${points[i].date.day}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
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
                  barGroups: [
                    for (var i = 0; i < n; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].amount * reveal,
                            width: barWidth,
                            color: _selected == null || _selected == i
                                ? scheme.primary
                                : scheme.primary.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppSpacing.xxs),
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
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: selected != null,
          child: Text(caption, style: muted),
        ),
        if (widget.average > 0)
          Text(
            'Dashed line: ${money(widget.average)} a day on average. Tap a '
            'day to see its total.',
            style: muted,
          ),
      ],
    );
  }
}
