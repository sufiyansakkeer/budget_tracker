import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';
import 'dashboard_info.dart';

/// One card answering "how much remains, how far along am I, how many days
/// are left" for the active budget. Replaces the separate Remaining Budget
/// and Budget Timeline cards so the same facts are not repeated.
class BudgetOverviewCard extends StatelessWidget {
  final BudgetSummaryEntity summary;
  final VoidCallback? onTap;

  const BudgetOverviewCard({super.key, required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = context.appColors;

    final utilization = summary.budgetUtilization;
    final overBudget = summary.remainingBudget < 0;
    final remainingColor = overBudget
        ? colors.error
        : AppProgress.colorFor(context, utilization);
    final usedPercent = (utilization * 100).clamp(0.0, 999.0);

    final span = summary.endDate.difference(summary.startDate).inDays + 1;
    final totalDays = span < 1 ? 1 : span;
    final dayNumber = (totalDays - summary.remainingDays + 1).clamp(
      1,
      totalDays,
    );
    final dateFmt = DateFormat('d MMM');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.mlg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        overBudget ? 'Over budget by' : 'Remaining in budget',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InfoIcon(
                      content: DashboardInfo.budgetOverview(summary.currency),
                    ),
                  ],
                ),
              ),
              Text(
                '${usedPercent.toStringAsFixed(0)}% used',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: remainingColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AnimatedAmount(
                  amount: summary.remainingBudget.abs(),
                  currency: summary.currency,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: overBudget ? colors.error : colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'of ${CurrencyFormatter.format(summary.monthlyAmount, code: summary.currency, decimalDigits: 0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          AppProgress(
            value: utilization,
            height: AppSizes.progressMd,
            semanticLabel: 'Budget used',
          ),
          const SizedBox(height: AppSpacing.md),

          // Timeline: day X of Y · N days left, with start/end dates.
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: AppSizes.iconXs,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Day $dayNumber of $totalDays · '
                  '${summary.remainingDays} '
                  '${summary.remainingDays == 1 ? 'day' : 'days'} left',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${dateFmt.format(summary.startDate)} – '
                '${dateFmt.format(summary.endDate)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgress(
            value: totalDays > 0 ? dayNumber / totalDays : 0,
            height: AppSizes.progressThin,
            color: colorScheme.primary.withValues(alpha: 0.7),
            semanticLabel: 'Budget period elapsed',
          ),
        ],
      ),
    );
  }
}
