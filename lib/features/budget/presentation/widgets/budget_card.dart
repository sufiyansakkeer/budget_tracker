import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/status_chip.dart';
import 'budget_visuals.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/widgets/animated_amount.dart';

/// A card summarizing a single budget in the list screen.
///
/// Hierarchy: name + period → remaining amount (primary) → spent / total →
/// progress → days left. The active budget is marked with a chip and a
/// tinted border so it is obvious at a glance.
class BudgetCard extends StatelessWidget {
  final BudgetEntity budget;
  final bool isActive;
  final VoidCallback? onTap;

  const BudgetCard({
    super.key,
    required this.budget,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final accent = BudgetVisuals.colorFor(context, budget);
    final now = DateTime.now();
    final phase = budget.phaseOn(now);

    final spent = (budget.monthlyAmount - budget.remainingAmount).clamp(
      0.0,
      double.infinity,
    );
    final utilization = budget.monthlyAmount <= 0
        ? 0.0
        : spent / budget.monthlyAmount;
    final overBudget = budget.remainingAmount < 0;
    final remainingColor = overBudget
        ? colors.error
        : AppProgress.colorFor(context, utilization);

    String money(double v) =>
        CurrencyFormatter.format(v, code: budget.currency, decimalDigits: 0);

    final String daysText;
    switch (phase) {
      case BudgetPhase.running:
        final left = budget.daysRemaining(now);
        daysText = '$left ${left == 1 ? 'day' : 'days'} left';
      case BudgetPhase.upcoming:
        final until = budget.startDate.difference(now).inDays + 1;
        daysText = 'Starts in $until ${until == 1 ? 'day' : 'days'}';
      case BudgetPhase.ended:
        daysText = 'Period ended';
      case BudgetPhase.archived:
        daysText = 'Archived';
    }

    return Semantics(
      button: onTap != null,
      label:
          '${budget.name}${isActive ? ', active budget' : ''}. '
          '${money(budget.remainingAmount)} remaining of '
          '${money(budget.monthlyAmount)}. $daysText.',
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: phase == BudgetPhase.archived ? 0.7 : 1,
        duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.smd),
          // The active budget's primary border animates in via AppCard.
          child: AppCard(
            onTap: onTap,
            borderColor: isActive ? theme.colorScheme.primary : null,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconTile(
                      icon: BudgetVisuals.iconFor(budget.icon),
                      color: accent,
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            budget.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            formatDateRange(budget.startDate, budget.endDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _PhaseChip(phase: phase, isActive: isActive),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            overBudget ? 'Over budget by' : 'Remaining',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          AnimatedAmount(
                            amount: budget.remainingAmount.abs(),
                            currency: budget.currency,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: overBudget
                                  ? colors.error
                                  : theme.colorScheme.onSurface,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${money(spent)} spent',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'of ${money(budget.monthlyAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppProgress(
                  value: utilization,
                  height: AppSizes.progressSm,
                  semanticLabel: 'Budget used',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    AnimatedPercent(
                      percent: (utilization * 100).clamp(0, 999).toDouble(),
                      suffix: '% used',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: remainingColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: AppSizes.iconXs,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      daysText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final BudgetPhase phase;
  final bool isActive;

  const _PhaseChip({required this.phase, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey('${phase.name}_$isActive'),
        child: _chip(context),
      ),
    );
  }

  Widget _chip(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    if (isActive) {
      return StatusChip(
        label: 'Active',
        color: theme.colorScheme.primary,
        icon: Icons.check_circle_rounded,
      );
    }
    return switch (phase) {
      BudgetPhase.running => const SizedBox.shrink(),
      BudgetPhase.upcoming => StatusChip(
        label: 'Upcoming',
        color: colors.info,
        icon: Icons.schedule_rounded,
      ),
      BudgetPhase.ended => StatusChip(
        label: 'Ended',
        color: theme.colorScheme.onSurfaceVariant,
        icon: Icons.event_busy_rounded,
      ),
      BudgetPhase.archived => StatusChip(
        label: 'Archived',
        color: theme.colorScheme.onSurfaceVariant,
        icon: Icons.archive_rounded,
      ),
    };
  }
}
