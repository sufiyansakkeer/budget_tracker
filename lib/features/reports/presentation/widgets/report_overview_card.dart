import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/report_overview.dart';

/// Highlights a single overview metric in a compact card.
class ReportOverviewCard extends StatelessWidget {
  final String title;
  final double amount;
  final String currency;
  final IconData icon;
  final Color color;

  const ReportOverviewCard({
    super.key,
    required this.title,
    required this.amount,
    required this.currency,
    required this.icon,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label:
          '$title: ${NumberFormat.currency(symbol: currency, decimalDigits: 0).format(amount)}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(color: theme.colorScheme.surfaceVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppSpacing.borderRadiusSm,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              NumberFormat.currency(
                symbol: currency,
                decimalDigits: 0,
              ).format(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A responsive grid of overview cards for the report.
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
    final cards = [
      ReportOverviewCard(
        title: 'Total Spending',
        amount: overview.totalSpending,
        currency: currency,
        icon: Icons.account_balance_wallet,
        color: AppColors.primary,
      ),
      ReportOverviewCard(
        title: 'Transactions',
        amount: overview.totalTransactions.toDouble(),
        currency: '',
        icon: Icons.receipt_long,
        color: AppColors.secondary,
      ),
      ReportOverviewCard(
        title: 'Avg Daily',
        amount: overview.averageDailySpending,
        currency: currency,
        icon: Icons.show_chart,
        color: AppColors.safeGreen,
      ),
      ReportOverviewCard(
        title: 'Avg / Txn',
        amount: overview.averageTransactionAmount,
        currency: currency,
        icon: Icons.trending_up,
        color: AppColors.warningOrange,
      ),
      ReportOverviewCard(
        title: 'Highest',
        amount: overview.highestExpense,
        currency: currency,
        icon: Icons.arrow_upward,
        color: AppColors.dangerRed,
      ),
      ReportOverviewCard(
        title: 'Lowest',
        amount: overview.lowestExpense,
        currency: currency,
        icon: Icons.arrow_downward,
        color: AppColors.safeGreen,
      ),
    ];

    return GridView.count(
      crossAxisCount: isWide ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: isWide ? 1.8 : 1.4,
      children: cards,
    );
  }
}
