import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/chart_reveal.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../reports/presentation/widgets/chart_card.dart';
import '../../domain/entities/pay_later_overview.dart';

/// The overview's two charts for one currency (spec §7): what was added to
/// tabs and paid each month, and what was owed at each month's end.
class PayLaterCharts extends StatelessWidget {
  final PayLaterAnalytics analytics;

  const PayLaterCharts({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AddedPaidChart(months: analytics.months, currency: analytics.currency),
        const SizedBox(height: AppSpacing.lg),
        OwedOverTimeChart(
          months: analytics.months,
          currency: analytics.currency,
        ),
      ],
    );
  }
}

String _monthLabel(DateTime month) => DateFormat('MMM').format(month);

/// A value axis with round ticks: an interval of 1, 2, 2.5 or 5 times a
/// power of ten giving about [targetTicks] steps, and a top that is the
/// first tick at or above the largest value, so the top line is labelled
/// too (no "2.33" or "0.575" ticks).
@visibleForTesting
abstract final class ChartScale {
  static const int targetTicks = 4;

  /// The axis top clears the largest value by at least this factor, so the
  /// top bar or line point is never clipped at the chart's edge.
  static const double headroom = 1.08;

  static ({double interval, double max}) of(double top) {
    if (top <= 0 || !top.isFinite) return (interval: 1, max: 1);
    final raw = top / targetTicks;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final residual = raw / magnitude;
    final step = residual <= 1
        ? 1.0
        : residual <= 2
        ? 2.0
        : residual <= 2.5
        ? 2.5
        : residual <= 5
        ? 5.0
        : 10.0;
    final interval = _clean(step * magnitude);
    final ticks = (top * headroom / interval - 1e-9).ceil();
    return (interval: interval, max: _clean(ticks * interval));
  }

  /// Drops binary noise (0.30000000000000004 → 0.3).
  static double _clean(double value) =>
      double.parse(value.toStringAsPrecision(12));

  /// A tick's label: compact, and free of floating-point noise.
  static String label(double value) =>
      NumberFormat.compact().format(_clean(value));
}

String _money(double value, String currency) =>
    CurrencyFormatter.format(value, code: currency);

TextStyle? _axisStyle(ThemeData theme) => theme.textTheme.labelSmall?.copyWith(
  color: theme.colorScheme.onSurfaceVariant,
);

/// Monthly added (bars in the primary colour) next to paid (bars in the
/// positive tone), last six months.
class AddedPaidChart extends StatelessWidget {
  final List<MonthPoint> months;
  final String currency;

  const AddedPaidChart({
    super.key,
    required this.months,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final addedColor = colorScheme.primary;
    final paidColor = context.tone(AppTone.positive).accent;
    final empty = months.every((m) => m.added <= 0 && m.paid <= 0);
    var top = 0.0;
    for (final m in months) {
      top = math.max(top, math.max(m.added, m.paid));
    }
    final scale = ChartScale.of(top);

    return ChartCard(
      title: 'Added and paid',
      caption: 'Last ${months.length} months · $currency',
      info: const InfoContent(
        title: 'Added and paid',
        whatIsThis:
            'What you put on your tabs and what you paid towards them, '
            'month by month.',
        howIsItCalculated:
            'Purchases count in the month of their date. Payments count in '
            'the month the money changed hands, not the day you recorded it.',
      ),
      child: empty
          ? const ChartPlaceholder(
              icon: Icons.bar_chart_rounded,
              message: 'Nothing added or paid in these months',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: AppSizes.chartHeight,
                  child: Semantics(
                    label: _summary(),
                    excludeSemantics: true,
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
                          maxY: scale.max,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) =>
                                  colorScheme.inverseSurface,
                              getTooltipItem: (group, _, rod, rodIndex) =>
                                  BarTooltipItem(
                                    '${rodIndex == 0 ? 'Added' : 'Paid'} '
                                    '${_money(rod.toY, currency)}',
                                    theme.textTheme.labelLarge!.copyWith(
                                      color: colorScheme.onInverseSurface,
                                    ),
                                  ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: scale.interval,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: colorScheme.outlineVariant,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: _titles(theme, scale.interval),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            for (var i = 0; i < months.length; i++)
                              BarChartGroupData(
                                x: i,
                                barsSpace: AppSpacing.xxs,
                                barRods: [
                                  _rod(months[i].added * reveal, addedColor),
                                  _rod(months[i].paid * reveal, paidColor),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChartLegendKey(color: addedColor, label: 'Added'),
                    ChartLegendKey(color: paidColor, label: 'Paid'),
                  ],
                ),
              ],
            ),
    );
  }

  BarChartRodData _rod(double value, Color color) => BarChartRodData(
    toY: value,
    color: color,
    width: 10,
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppSpacing.radiusXs),
    ),
  );

  FlTitlesData _titles(ThemeData theme, double interval) => FlTitlesData(
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        interval: interval,
        getTitlesWidget: (value, meta) =>
            Text(ChartScale.label(value), style: _axisStyle(theme)),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (index < 0 || index >= months.length) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _monthLabel(months[index].month),
              style: _axisStyle(theme),
            ),
          );
        },
      ),
    ),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );

  String _summary() => [
    'Bar chart of added and paid by month',
    for (final m in months)
      '${_monthLabel(m.month)}: added ${_money(m.added, currency)}, '
          'paid ${_money(m.paid, currency)}',
  ].join('. ');
}

/// What was still owed at the end of each of the last six months, tab by
/// tab: a tab in credit adds nothing and never offsets another tab's debt,
/// so the last point matches the headline "Owed".
class OwedOverTimeChart extends StatelessWidget {
  final List<MonthPoint> months;
  final String currency;

  const OwedOverTimeChart({
    super.key,
    required this.months,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lineColor = colorScheme.primary;
    final owed = [for (final m in months) math.max(0.0, m.owedAtEnd)];
    final top = owed.fold(0.0, math.max);

    return ChartCard(
      title: 'Owed at month end',
      caption: 'Last ${months.length} months · $currency',
      info: const InfoContent(
        title: 'Owed at month end',
        whatIsThis:
            'How much you owed across your tabs at the end of each month.',
        howIsItCalculated:
            'For each tab: everything bought on it up to the last day of the '
            'month, minus everything paid to it by then. A tab in credit '
            "counts as nothing owed; its credit doesn't reduce another tab. "
            'This month matches what you owe today.',
      ),
      child: top <= 0
          ? const ChartPlaceholder(
              message: 'Nothing was owed at the end of these months',
            )
          : SizedBox(
              height: AppSizes.chartHeightSm,
              child: Semantics(
                label: [
                  'Line chart of what was owed at month end',
                  for (var i = 0; i < months.length; i++)
                    '${_monthLabel(months[i].month)}: '
                        '${_money(owed[i], currency)}',
                ].join('. '),
                excludeSemantics: true,
                child: ChartReveal(
                  builder: (context, reveal, revealing) {
                    final chart = _chart(context, lineColor, owed, top);
                    if (reveal >= 1) return chart;
                    return ClipRect(
                      clipper: _RevealClipper(reveal),
                      child: chart,
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _chart(
    BuildContext context,
    Color lineColor,
    List<double> owed,
    double top,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scale = ChartScale.of(top);
    return LineChart(
      duration: AppMotion.respectReducedMotion(context, AppMotion.emphasized),
      curve: AppMotion.value,
      LineChartData(
        minX: 0,
        maxX: (months.length - 1).toDouble(),
        minY: 0,
        maxY: scale.max,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  _money(spot.y, currency),
                  theme.textTheme.labelLarge!.copyWith(
                    color: colorScheme.onInverseSurface,
                  ),
                ),
            ],
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: scale.interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colorScheme.outlineVariant, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: scale.interval,
              getTitlesWidget: (value, meta) =>
                  Text(ChartScale.label(value), style: _axisStyle(theme)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 ||
                    index >= months.length ||
                    value != index.toDouble()) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    _monthLabel(months[index].month),
                    style: _axisStyle(theme),
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
              for (var i = 0; i < owed.length; i++)
                FlSpot(i.toDouble(), owed[i]),
            ],
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: lineColor,
                strokeWidth: 2,
                strokeColor: colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.16),
                  lineColor.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A short coloured bar and its label, under a chart.
class ChartLegendKey extends StatelessWidget {
  final Color color;
  final String label;

  const ChartLegendKey({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.md,
          height: AppSpacing.xs + 1,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppSpacing.borderRadiusFull,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: _axisStyle(theme)),
      ],
    );
  }
}

/// Reveals the line left to right while it first appears.
class _RevealClipper extends CustomClipper<Rect> {
  final double progress;

  const _RevealClipper(this.progress);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, -8, size.width * progress, size.height + 16);

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.progress != progress;
}
