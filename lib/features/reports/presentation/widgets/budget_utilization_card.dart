import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';

/// Budget progress for the active budget: share of the total amount used,
/// with spent and remaining figures. Animates to new values.
class BudgetUtilizationCard extends StatelessWidget {
  final double spent;
  final double remaining;
  final double monthly;
  final String currency;

  const BudgetUtilizationCard({
    super.key,
    required this.spent,
    required this.remaining,
    required this.monthly,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final utilization = monthly <= 0 ? 0.0 : spent / monthly;
    final overBudget = spent > monthly && monthly > 0;
    final color = overBudget
        ? colors.error
        : AppProgress.colorFor(context, utilization);
    final s = CurrencyFormatter.symbolFor(currency);
    final (icon, label) = utilization >= 1.0
        ? (Icons.error_rounded, 'Over budget')
        : utilization >= 0.8
        ? (Icons.warning_amber_rounded, 'Near limit')
        : (Icons.check_circle_rounded, 'On track');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.mlg),
      child: Row(
        children: [
          AppProgressRing(
            value: utilization,
            color: color,
            semanticLabel: 'Budget used',
            center: AnimatedPercent(
              percent: (utilization * 100).clamp(0, 999),
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Budget progress',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    InfoIcon(
                      content: InfoContent(
                        title: 'Budget progress',
                        whatIsThis:
                            'What share of your active budget\'s total '
                            'amount has been spent so far in its period.',
                        howIsItCalculated:
                            'Progress = Total spent ÷ Budget amount\n\n'
                            "Total spent covers the whole budget period, "
                            'regardless of the report period selected above.',
                        example:
                            'Budget: ${s}30,000 · Spent: ${s}18,000\n'
                            'Progress: 60%',
                        additionalNotes:
                            '• Shown only when the selected period falls in '
                            'the current calendar month\n'
                            '• Status: On track below 80%, Near limit at '
                            '80–100%, Over budget above 100%',
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(icon, size: AppSizes.iconSm, color: color),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _Figure(
                        label: 'Spent',
                        amount: spent,
                        currency: currency,
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        label: overBudget ? 'Over by' : 'Remaining',
                        amount: overBudget ? spent - monthly : remaining,
                        currency: currency,
                        color: overBudget ? colors.error : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color? color;

  const _Figure({
    required this.label,
    required this.amount,
    required this.currency,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        AnimatedAmount(
          amount: amount,
          currency: currency,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
