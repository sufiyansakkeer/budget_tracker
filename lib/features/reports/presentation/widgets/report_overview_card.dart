import 'package:flutter/material.dart';
import '../../../../core/currency/currency_formatter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/report_overview.dart';

/// A prominent hero card showing the report's total spending, with a compact
/// set of supporting metrics below.
class ReportHeroCard extends StatelessWidget {
  final ReportOverview overview;
  final String currency;

  const ReportHeroCard({
    super.key,
    required this.overview,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSpending = CurrencyFormatter.format(
      overview.totalSpending,
      code: currency,
      decimalDigits: 0,
    );

    return AppCard(
      color: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Spending',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            totalSpending,
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${overview.totalTransactions} transactions',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// A concise metric tile used in the compact report overview grid.
class _OverviewMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// A consolidated overview layout for the report screen: a total-spending hero
/// plus a compact grid of the remaining metrics transaction, avg daily, avg
/// per-transaction, highest, and lowest.
class ReportOverviewGrid extends StatelessWidget {
  final ReportOverview overview;
  final String currency;

  const ReportOverviewGrid({
    super.key,
    required this.overview,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    String fmt(double v) =>
        CurrencyFormatter.format(v, code: currency, decimalDigits: 0);

    final metrics = [
      _OverviewMetric(
        title: 'Avg Daily',
        value: fmt(overview.averageDailySpending),
        icon: Icons.show_chart_rounded,
        color: AppColors.safeGreen,
      ),
      _OverviewMetric(
        title: 'Avg / Txn',
        value: fmt(overview.averageTransactionAmount),
        icon: Icons.trending_up_rounded,
        color: AppColors.warningOrange,
      ),
      _OverviewMetric(
        title: 'Highest',
        value: fmt(overview.highestExpense),
        icon: Icons.arrow_upward_rounded,
        color: AppColors.dangerRed,
      ),
      _OverviewMetric(
        title: 'Lowest',
        value: fmt(overview.lowestExpense),
        icon: Icons.arrow_downward_rounded,
        color: AppColors.safeGreen,
      ),
    ].where((m) => m.value.isNotEmpty);

    return Column(
      children: [
        ReportHeroCard(overview: overview, currency: currency),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: isWide ? 2.2 : 1.9,
          children: metrics.toList(),
        ),
      ],
    );
  }
}
