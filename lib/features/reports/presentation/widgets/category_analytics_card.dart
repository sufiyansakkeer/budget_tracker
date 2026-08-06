import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../domain/entities/category_analytics.dart';

/// Lists category analytics sorted by highest spending first.
class CategoryAnalyticsCard extends StatelessWidget {
  final List<CategoryAnalytics> analytics;
  final String currency;

  const CategoryAnalyticsCard({
    super.key,
    required this.analytics,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...analytics]
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: theme.colorScheme.surfaceVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Analytics',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (sorted.isEmpty)
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'No category data',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < sorted.length; i++) ...[
              _CategoryRow(analytics: sorted[i], currency: currency),
              if (i != sorted.length - 1) const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryAnalytics analytics;
  final String currency;

  const _CategoryRow({required this.analytics, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = CategoryVisuals.colorFor(analytics.colorHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                analytics.categoryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${analytics.percentageOfTotal.toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total: ${NumberFormat.currency(symbol: currency, decimalDigits: 0).format(analytics.totalAmount)} · ${analytics.transactionCount} txns',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              'Avg: ${NumberFormat.currency(symbol: currency, decimalDigits: 0).format(analytics.averageTransaction)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppSpacing.borderRadiusSm,
          child: LinearProgressIndicator(
            value: (analytics.percentageOfTotal / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
