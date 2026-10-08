import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/chart_reveal.dart';
import '../../domain/entities/spending_pace.dart';
import 'safe_to_spend_copy.dart';

/// "Am I spending faster or slower than I should?" as one sentence and one
/// small chart: discretionary spending so far (solid) against an even pace
/// through the period (dashed), from the domain's [SpendingPace].
///
/// The line is caution amber when spending runs ahead of the even pace and
/// positive green when it does not; the figure itself is in the sentence.
class SpendingPaceSection extends StatelessWidget {
  final SpendingPace pace;

  const SpendingPaceSection({super.key, required this.pace});

  /// "About ₹6,330 more than an even pace by today" / "… less …" / "Right
  /// on an even pace so far". Formats the domain's difference in whole
  /// units, because it is measured against a plan, not a record.
  static String caption(SpendingPace pace) {
    final gap = CurrencyFormatter.format(
      pace.aheadOfPlan.abs(),
      code: pace.currency,
      decimalDigits: 0,
    );
    final zero = CurrencyFormatter.format(0, code: pace.currency);
    if (gap == zero) return 'Right on an even pace so far';
    return pace.aheadOfPlan > 0
        ? 'About $gap more than an even pace by today'
        : 'About $gap less than an even pace by today';
  }

  static String _semantics(SpendingPace pace) {
    final spent = SafeToSpendCopy.amount(pace.actualToDate, pace.currency);
    final planned = SafeToSpendCopy.amount(pace.plannedToDate, pace.currency);
    return 'Spending pace. ${caption(pace)}. Spent $spent by day '
        '${pace.daysPassed} of ${pace.totalDays}; an even pace would be '
        '$planned by today.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ahead = pace.aheadOfPlan > 0;
    final line = context.tone(ahead ? AppTone.caution : AppTone.positive);

    return AppSection(
      title: 'Spending pace',
      child: Semantics(
        container: true,
        label: _semantics(pace),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(caption(pace), style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  // A wide, short chart: shape matters here, not values.
                  height: (constraints.maxWidth * 0.36).clamp(
                    AppSizes.chartHeightSm * 0.8,
                    AppSizes.chartHeight,
                  ),
                  child: ChartReveal(
                    builder: (context, reveal, revealing) {
                      final chart = _chart(context, line.accent);
                      if (reveal >= 1) return chart;
                      return ClipRect(
                        clipper: _RevealClipper(reveal),
                        child: chart,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  _Key(color: line.accent, label: 'Spent so far'),
                  _Key(
                    color: colorScheme.onSurfaceVariant,
                    label: 'Even pace',
                    dashed: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chart(BuildContext context, Color lineColor) {
    final colorScheme = Theme.of(context).colorScheme;
    final top = [
      pace.plannedTotal,
      pace.actualToDate,
    ].reduce((a, b) => a > b ? a : b);
    return LineChart(
      duration: AppMotion.respectReducedMotion(context, AppMotion.emphasized),
      curve: AppMotion.value,
      LineChartData(
        minX: 0,
        maxX: pace.totalDays.toDouble(),
        minY: 0,
        maxY: top <= 0 ? 1 : top * 1.08,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 0),
              FlSpot(pace.totalDays.toDouble(), pace.plannedTotal),
            ],
            color: colorScheme.onSurfaceVariant,
            barWidth: 1.5,
            dashArray: const [4, 4],
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: [
              const FlSpot(0, 0),
              for (var i = 0; i < pace.cumulative.length; i++)
                FlSpot((i + 1).toDouble(), pace.cumulative[i]),
            ],
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              checkToShowDot: (spot, bar) => spot == bar.spots.last,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
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

class _Key extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _Key({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: AppSpacing.md,
          child: Row(
            children: [
              for (var i = 0; i < (dashed ? 2 : 1); i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Container(
                    height: AppSpacing.xxs + 1,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: AppSpacing.borderRadiusFull,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Reveals the chart left to right while it first appears.
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
