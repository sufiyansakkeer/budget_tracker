import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_metric.dart';
import '../../../../core/widgets/app_money.dart';
import '../../domain/entities/report_data.dart';
import 'report_copy.dart';

/// The answer first: what was spent in the period, how that compares with
/// the stretch just before it, then the daily average, how many expenses
/// and the biggest one.
class ReportTotal extends StatelessWidget {
  final ReportData data;
  final String currency;

  const ReportTotal({super.key, required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overview = data.overview;
    final comparison = ReportCopy.comparison(data);
    final count = overview.totalTransactions;
    final total = AppMoney.format(overview.totalSpending, currency: currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              'Spent $total'
              '${comparison == null ? '' : '. ${comparison.text}'}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spent',
                style: context.appTypography.eyebrow.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AppMoney(
                amount: overview.totalSpending,
                currency: currency,
                role: MoneyRole.display,
              ),
              if (comparison != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Icon(
                        switch (comparison.tone) {
                          AppTone.caution => Icons.arrow_upward_rounded,
                          AppTone.positive => Icons.arrow_downward_rounded,
                          _ => Icons.drag_handle_rounded,
                        },
                        size: AppSizes.iconSm,
                        color: context.tone(comparison.tone).accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        comparison.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppMetric(
                label: 'Daily average',
                value: AppMoney(
                  amount: overview.averageDailySpending,
                  currency: currency,
                ),
              ),
            ),
            Expanded(
              child: AppMetric(
                label: count == 1 ? 'Expense' : 'Expenses',
                value: Text('$count', style: context.appTypography.moneyBody),
              ),
            ),
            Expanded(
              child: AppMetric(
                label: 'Biggest',
                alignEnd: true,
                value: AppMoney(
                  amount: overview.highestExpense,
                  currency: currency,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
