import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../domain/entities/category_analytics.dart';
import '../../domain/entities/category_slice.dart';
import 'chart_card.dart';

/// Where the money went: a donut of category shares with a matching ranked
/// list (amount, share, number of expenses). Small categories beyond the
/// top five are folded into "Other".
class CategoryBreakdownCard extends StatefulWidget {
  final List<CategorySlice> slices;
  final List<CategoryAnalytics> analytics;
  final List<ExpenseCategory> categories;
  final String currency;

  const CategoryBreakdownCard({
    super.key,
    required this.slices,
    required this.analytics,
    required this.categories,
    required this.currency,
  });

  @override
  State<CategoryBreakdownCard> createState() => _CategoryBreakdownCardState();
}

class _CategoryBreakdownCardState extends State<CategoryBreakdownCard> {
  static const int _topCount = 5;
  bool _showAll = false;
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = CurrencyFormatter.symbolFor(widget.currency);
    final sorted = [...widget.analytics]
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    final total = sorted.fold<double>(0, (sum, a) => sum + a.totalAmount);
    final hasData = sorted.isNotEmpty && total > 0;

    final visible = _showAll || sorted.length <= _topCount + 1
        ? sorted
        : sorted.take(_topCount).toList();
    final rest = sorted.skip(visible.length).toList();
    final otherTotal = rest.fold<double>(0, (sum, a) => sum + a.totalAmount);
    final otherCount = rest.fold<int>(0, (sum, a) => sum + a.transactionCount);

    final top = hasData ? sorted.first : null;

    return ChartCard(
      title: 'Where it went',
      caption: top == null
          ? null
          : '${top.categoryName} took the biggest share '
                '(${top.percentageOfTotal.toStringAsFixed(0)}%)',
      info: InfoContent(
        title: 'Where it went',
        whatIsThis:
            "Your active budget's spending in the selected period, broken "
            'down by category.',
        howIsItCalculated:
            'Each category adds up the expenses assigned to it.\n'
            'Share = Category total ÷ Total spending.\n'
            'Categories are listed from largest to smallest; the smallest '
            'ones are grouped as "Other".',
        example:
            'Food: ${s}4,500 (30%)\n'
            'Shopping: ${s}3,000 (20%)\n'
            'Total: ${s}15,000',
      ),
      child: !hasData
          ? const ChartPlaceholder(
              icon: Icons.donut_large_rounded,
              message: 'No category spending to show yet',
            )
          : Column(
              children: [
                SizedBox(
                  height: 168,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Semantics(
                          label:
                              'Donut chart of spending by category, '
                              '${sorted.length} categories',
                          child: PieChart(
                            duration: AppMotion.respectReducedMotion(
                              context,
                              AppMotion.emphasized,
                            ),
                            curve: AppMotion.value,
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 44,
                              startDegreeOffset: -90,
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  final index = response
                                      ?.touchedSection
                                      ?.touchedSectionIndex;
                                  if (!event.isInterestedForInteractions ||
                                      index == null ||
                                      index < 0) {
                                    if (_touched != null) {
                                      setState(() => _touched = null);
                                    }
                                    return;
                                  }
                                  if (index != _touched) {
                                    setState(() => _touched = index);
                                  }
                                },
                              ),
                              sections: [
                                for (var i = 0; i < visible.length; i++)
                                  PieChartSectionData(
                                    value: visible[i].totalAmount,
                                    color: _colorFor(visible[i], i),
                                    radius: _touched == i ? 30 : 24,
                                    showTitle: false,
                                  ),
                                if (otherTotal > 0)
                                  PieChartSectionData(
                                    value: otherTotal,
                                    color: theme.colorScheme.outlineVariant,
                                    radius: _touched == visible.length
                                        ? 30
                                        : 24,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: _CenterLabel(
                            touched: _touched == null
                                ? null
                                : _touched! < visible.length
                                ? (
                                    visible[_touched!].categoryName,
                                    visible[_touched!].totalAmount,
                                    visible[_touched!].percentageOfTotal,
                                  )
                                : (
                                    'Other',
                                    otherTotal,
                                    total > 0 ? otherTotal / total * 100 : 0,
                                  ),
                            total: total,
                            currency: widget.currency,
                            categoryCount: sorted.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < visible.length; i++)
                  _CategoryRow(
                    name: visible[i].categoryName,
                    color: _colorFor(visible[i], i),
                    amount: visible[i].totalAmount,
                    share: visible[i].percentageOfTotal / 100,
                    count: visible[i].transactionCount,
                    currency: widget.currency,
                    highlighted: _touched == i,
                  ),
                if (otherTotal > 0)
                  _CategoryRow(
                    name: 'Other (${rest.length})',
                    color: theme.colorScheme.outlineVariant,
                    amount: otherTotal,
                    share: total > 0 ? otherTotal / total : 0,
                    count: otherCount,
                    currency: widget.currency,
                    highlighted: _touched == visible.length,
                  ),
                if (sorted.length > _topCount + 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      child: Text(
                        _showAll
                            ? 'Show top $_topCount'
                            : 'Show all ${sorted.length}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Color _colorFor(CategoryAnalytics analytics, int index) {
    final hex = analytics.colorHex.isNotEmpty
        ? analytics.colorHex
        : _hexFromCategories(analytics.categoryId);
    if (hex != null && hex.isNotEmpty) {
      return CategoryVisuals.adaptiveColor(context, hex);
    }
    final colors = context.appColors;
    final fallback = [
      colors.primary,
      colors.secondary,
      colors.tertiary,
      colors.primaryLight,
      colors.secondaryLight,
      colors.tertiaryLight,
    ];
    return fallback[index % fallback.length];
  }

  String? _hexFromCategories(String id) {
    for (final c in widget.categories) {
      if (c.id == id) return c.colorHex;
    }
    return null;
  }
}

class _CenterLabel extends StatelessWidget {
  final (String, double, double)? touched;
  final double total;
  final String currency;
  final int categoryCount;

  const _CenterLabel({
    required this.touched,
    required this.total,
    required this.currency,
    required this.categoryCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, amount, share) = touched ?? ('Total', total, 100.0);
    return AnimatedSwitcher(
      duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
      child: Column(
        key: ValueKey(label),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(
                amount,
                code: currency,
                decimalDigits: 0,
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ),
          Text(
            touched == null
                ? '$categoryCount ${categoryCount == 1 ? 'category' : 'categories'}'
                : '${share.toStringAsFixed(0)}% of total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final Color color;
  final double amount;
  final double share;
  final int count;
  final String currency;
  final bool highlighted;

  const _CategoryRow({
    required this.name,
    required this.color,
    required this.amount,
    required this.share,
    required this.count,
    required this.currency,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: highlighted ? color.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                CurrencyFormatter.format(
                  amount,
                  code: currency,
                  decimalDigits: 0,
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${(share * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const SizedBox(width: 10 + AppSpacing.sm),
              Expanded(
                child: AppProgress(
                  value: share,
                  height: AppSizes.progressThin,
                  color: color,
                  semanticLabel: '$name share',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 84,
                child: Text(
                  '$count ${count == 1 ? 'expense' : 'expenses'}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
