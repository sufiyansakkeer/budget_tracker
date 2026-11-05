import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/info_content.dart';
import '../../domain/entities/monthly_spending_bucket.dart';
import '../../domain/entities/report_period.dart';
import 'chart_card.dart';
import 'report_copy.dart';
import '../../../../core/widgets/chart_reveal.dart';

/// Spending grouped into weeks (month views) or months (year view).
class BarChartCard extends StatelessWidget {
  final List<SpendingBucket> buckets;
  final String currency;

  /// The report's range. A first or last bucket that runs past it is
  /// labelled by the days it covers inside it.
  final ReportRange? range;

  const BarChartCard({
    super.key,
    required this.buckets,
    required this.currency,
    this.range,
  });

  /// "week", "month" or "year", read from the buckets themselves (a week
  /// or a month apart), so the label always matches what is drawn. Before,
  /// a custom range over 62 days drew months labelled "week".
  String get unit => _unitOf(buckets);

  static String _unitOf(List<SpendingBucket> buckets) =>
      buckets.length > 1 &&
          buckets[1].startDate.difference(buckets[0].startDate).inDays >= 28
      ? (buckets.length > _maxMonths ? 'year' : 'month')
      : 'week';

  /// More months than this are drawn as years: 320 thin bars read as
  /// noise.
  static const int _maxMonths = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unit = this.unit;
    final bars = _bars(unit);
    final active = bars.where((b) => b.amount > 0).toList();
    final spansYears =
        bars.isNotEmpty && bars.first.start.year != bars.last.end.year;
    String money(double v) =>
        CurrencyFormatter.format(v, code: currency, decimalDigits: 0);
    String name(_Bar bar) => _name(bar, unit, spansYears: spansYears);
    // Label every few bars so the axis never crowds, fewer at large text.
    final perAxis = math.max(
      2,
      (6 / MediaQuery.textScalerOf(context).scale(1)).floor(),
    );
    final step = math.max(1, (bars.length / perAxis).ceil());

    _Bar? top;
    for (final b in bars) {
      if (top == null || b.amount > top.amount) top = b;
    }
    final title = 'Spending by $unit';

    return ChartCard(
      title: title,
      caption: top != null && top.amount > 0
          ? 'Highest $unit: ${name(top)} · ${money(top.amount)}'
          : null,
      info: InfoContent(
        title: title,
        whatIsThis:
            "Your active budget's spending in the selected period, grouped "
            'by $unit, so you can see which ${unit}s were heavier.',
        howIsItCalculated:
            'Expenses are added up per $unit based on their recorded date. '
            '${unit == 'week' ? 'Weeks start on Monday. ' : ''}'
            'A first or last $unit cut short by the period is named by the '
            'days it covers.',
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
                label:
                    '$title: ${[for (final b in bars) '${name(b)}, ${AppMoney.format(b.amount, currency: currency)}'].join('; ')}',
                excludeSemantics: true,
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
                      maxY: _maxY(bars),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => colorScheme.inverseSurface,
                          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                            '${name(bars[group.x])} · '
                            '${money(bars[group.x].amount)}',
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
                              if (index < 0 ||
                                  index >= bars.length ||
                                  index % step != 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Text(
                                  _axisLabel(
                                    bars[index],
                                    unit,
                                    spansYears: spansYears,
                                  ),
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
                        for (var i = 0; i < bars.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: bars[i].amount * reveal,
                                // Every bar meets the 3:1 non-text floor;
                                // the highest is told apart by hue
                                // (UX-070).
                                color: identical(bars[i], top)
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                                width: bars.length > 8 ? 12 : 20,
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

  /// The bars as drawn: the buckets (or years, for a long range), each
  /// with the days it covers inside the report's range.
  List<_Bar> _bars(String unit) {
    DateTime endOf(DateTime start) => switch (unit) {
      'week' => start.addDays(6),
      'month' => DateTime(start.year, start.month + 1, 0),
      _ => DateTime(start.year, 12, 31),
    };
    final grouped = <(DateTime, double)>[];
    for (final b in buckets) {
      final start = unit == 'year' ? DateTime(b.startDate.year) : b.startDate;
      if (grouped.isNotEmpty && grouped.last.$1 == start) {
        grouped.last = (start, grouped.last.$2 + b.amount);
      } else {
        grouped.add((start, b.amount));
      }
    }
    final from = range?.start.dateOnly;
    final to = range?.end.dateOnly;
    return [
      for (final (start, amount) in grouped)
        _Bar(
          start: from != null && start.isBefore(from) ? from : start,
          end: to != null && endOf(start).isAfter(to) ? to : endOf(start),
          amount: amount,
          whole:
              (from == null || !start.isBefore(from)) &&
              (to == null || !endOf(start).isAfter(to)),
        ),
    ];
  }

  /// How a bar is named in the caption, tooltip and spoken label: the days
  /// of a week ("1 – 4 Oct"), a month ("Sep", "Dec 2025" across years) or a
  /// year. A month or year cut short by the range names its days too.
  static String _name(_Bar bar, String unit, {required bool spansYears}) {
    if (unit == 'week' || !bar.whole) {
      final days = ReportCopy.span(bar.start, bar.end);
      return spansYears && unit != 'week' ? '$days ${bar.end.year}' : days;
    }
    if (unit == 'year') return '${bar.start.year}';
    return DateFormat(spansYears ? 'MMM yyyy' : 'MMM').format(bar.start);
  }

  /// Short axis labels: "1 Oct" for weeks, "Sep" (or "Sep '25" across
  /// years) for months, "2025" for years.
  static String _axisLabel(_Bar bar, String unit, {required bool spansYears}) {
    return switch (unit) {
      'week' => DateFormat('d MMM').format(bar.start),
      'month' => DateFormat(spansYears ? "MMM ''yy" : 'MMM').format(bar.start),
      _ => '${bar.start.year}',
    };
  }

  static double _maxY(List<_Bar> bars) {
    var max = 0.0;
    for (final bar in bars) {
      if (bar.amount > max) max = bar.amount;
    }
    return max <= 0 ? 1 : max * 1.15;
  }
}

/// One drawn bar: its days inside the report's range and its total.
class _Bar {
  final DateTime start;
  final DateTime end;
  final double amount;

  /// Whether the bar covers its whole week, month or year.
  final bool whole;

  const _Bar({
    required this.start,
    required this.end,
    required this.amount,
    required this.whole,
  });
}
