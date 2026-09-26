import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../domain/entities/category_comparison.dart';
import '../../domain/entities/report_period.dart';
import 'chart_card.dart';

/// Which categories moved most versus the previous period.
///
/// Shows up to [maxRows] categories ordered by the size of the change, with
/// the current amount and a signed delta. Spending less reads as success,
/// more as a warning; a category with no previous spending is marked "New".
class CategoryComparisonCard extends StatelessWidget {
  final List<CategoryComparison> comparison;
  final List<ExpenseCategory> categories;
  final ReportRange range;
  final String currency;
  final int maxRows;

  const CategoryComparisonCard({
    super.key,
    required this.comparison,
    required this.categories,
    required this.range,
    required this.currency,
    this.maxRows = 5,
  });

  /// Whether there is something to compare against.
  static bool hasComparison(List<CategoryComparison> comparison) =>
      comparison.any((c) => c.previousAmount > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = comparison.take(maxRows).toList();
    final iconById = {for (final c in categories) c.id: c.icon};
    final days = range.dayCount;
    final previousStart = range.start.subtract(Duration(days: days));
    final previousEnd = range.start.subtract(const Duration(days: 1));
    final fmt = DateFormat('d MMM');
    final s = CurrencyFormatter.symbolFor(currency);

    return ChartCard(
      title: 'Categories vs previous period',
      caption:
          'Compared with ${fmt.format(previousStart)} – '
          '${fmt.format(previousEnd)} ($days ${days == 1 ? 'day' : 'days'})',
      info: InfoContent(
        title: 'Categories vs previous period',
        whatIsThis:
            'Which categories you spent more or less on than in the same '
            'number of days just before this period.',
        howIsItCalculated:
            'For every category: Change = This period − Previous period, '
            'where the previous period has the same length and ends the day '
            'before this one starts. Categories are ordered by the size of '
            'the change, biggest first.',
        example:
            'Food this period: ${s}6,000\n'
            'Food previous period: ${s}5,000\n'
            'Change: +${s}1,000 (20% up)',
        additionalNotes:
            '• "New" means nothing was spent on that category in the '
            'previous period\n'
            '• Only the five largest changes are listed',
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: AppSpacing.md,
                color: theme.colorScheme.outlineVariant,
              ),
            _ComparisonRow(
              key: ValueKey('comparison_${rows[i].categoryId}'),
              item: rows[i],
              icon: CategoryVisuals.iconFor(
                iconById[rows[i].categoryId] ?? 'category',
              ),
              currency: currency,
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final CategoryComparison item;
  final IconData icon;
  final String currency;

  const _ComparisonRow({
    super.key,
    required this.item,
    required this.icon,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final color = CategoryVisuals.adaptiveColor(context, item.colorHex);
    final diff = item.difference;
    final flat = diff.abs() < 0.5;

    final Color deltaColor;
    final IconData deltaIcon;
    final String deltaText;
    if (item.isNew) {
      deltaColor = colors.info;
      deltaIcon = Icons.fiber_new_rounded;
      deltaText = 'New';
    } else if (flat) {
      deltaColor = theme.colorScheme.onSurfaceVariant;
      deltaIcon = Icons.drag_handle_rounded;
      deltaText = 'Same';
    } else {
      final up = diff > 0;
      deltaColor = up ? colors.warning : colors.success;
      deltaIcon = up
          ? Icons.arrow_upward_rounded
          : Icons.arrow_downward_rounded;
      final pct = item.percentageChange;
      final amount = CurrencyFormatter.format(
        diff.abs(),
        code: currency,
        decimalDigits: 0,
      );
      deltaText = pct == null
          ? '${up ? '+' : '−'}$amount'
          : '${up ? '+' : '−'}$amount · ${pct.abs().toStringAsFixed(0)}%';
    }

    return Semantics(
      label:
          '${item.categoryName}: ${CurrencyFormatter.format(item.currentAmount, code: currency, decimalDigits: 0)} this period, '
          '${item.isNew
              ? 'new'
              : flat
              ? 'unchanged'
              : (diff > 0 ? 'up' : 'down')} '
          '${flat || item.isNew ? '' : CurrencyFormatter.format(diff.abs(), code: currency, decimalDigits: 0)}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            IconTile(icon: icon, color: color, size: AppSizes.avatarSm),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Text(
                item.categoryName,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedAmount(
                  amount: item.currentAmount,
                  currency: currency,
                  decimalDigits: 0,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                AnimatedSwitcher(
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.fast,
                  ),
                  child: Row(
                    key: ValueKey(deltaText),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(deltaIcon, size: AppSizes.iconXs, color: deltaColor),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        deltaText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: deltaColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
