import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/currency/currency_formatter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../domain/entities/category_slice.dart';

/// Card containing a category distribution pie chart with a legend.
class PieChartCard extends StatelessWidget {
  final List<CategorySlice> slices;
  final List<ExpenseCategory> categories;
  final String currency;

  const PieChartCard({
    super.key,
    required this.slices,
    required this.categories,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = slices.isEmpty || slices.every((s) => s.amount <= 0);
    final total = slices.fold<double>(0, (sum, s) => sum + s.amount);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Breakdown',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (empty)
            SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'No category spending to show',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 180,
                    child: _PieChart(slices: slices, categories: categories),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (slices.isNotEmpty)
                  Expanded(
                    child: _Legend(
                      slices: slices,
                      categories: categories,
                      total: total,
                    ),
                  ),
              ],
            ),
          if (!empty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Total: ${CurrencyFormatter.format(total, code: currency, decimalDigits: 0)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  final List<CategorySlice> slices;
  final List<ExpenseCategory> categories;

  const _PieChart({required this.slices, required this.categories});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          for (var i = 0; i < slices.length; i++)
            PieChartSectionData(
              value: slices[i].amount,
              color: _colorFor(slices[i], i),
              radius: 40,
              showTitle: false,
            ),
        ],
      ),
    );
  }

  Color _colorFor(CategorySlice slice, int index) {
    for (final category in categories) {
      if (category.id == slice.categoryId) {
        return CategoryVisuals.colorFor(category.colorHex);
      }
    }
    return _palette[index % _palette.length];
  }

  static const List<Color> _palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.safeGreen,
    AppColors.warningOrange,
    AppColors.dangerRed,
  ];
}

class _Legend extends StatelessWidget {
  final List<CategorySlice> slices;
  final List<ExpenseCategory> categories;
  final double total;

  const _Legend({
    required this.slices,
    required this.categories,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < slices.length; i++) ...[
          _LegendRow(
            slice: slices[i],
            categories: categories,
            index: i,
            total: total,
          ),
          if (i != slices.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final CategorySlice slice;
  final List<ExpenseCategory> categories;
  final int index;
  final double total;

  const _LegendRow({
    required this.slice,
    required this.categories,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = total <= 0 ? 0.0 : (slice.amount / total) * 100;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: _color(), shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            slice.categoryName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _color() {
    for (final category in categories) {
      if (category.id == slice.categoryId) {
        return CategoryVisuals.colorFor(category.colorHex);
      }
    }
    return _palette[index % _palette.length];
  }

  static const List<Color> _palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.safeGreen,
    AppColors.warningOrange,
    AppColors.dangerRed,
  ];
}
