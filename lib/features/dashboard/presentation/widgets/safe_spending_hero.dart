import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/theme/contrast.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import 'dashboard_info.dart';
import 'spending_status.dart';
import '../../../../core/navigation/push_unique.dart';

/// The dashboard's primary element: how much the user can still spend today
/// in the active budget, what they have spent, and whether they are on track.
///
/// Uses the per-budget calculation from the Budget Engine as-is; the widget
/// only presents it.
class SafeSpendingHero extends StatelessWidget {
  final BudgetDailyLimitEntity limit;

  const SafeSpendingHero({super.key, required this.limit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = SpendingStatusVisuals.of(context, limit.status);
    final over = limit.isOverLimit;
    // Show the true ratio so the bar can indicate over-spend; AppProgress
    // clamps the drawn value but colors by the unclamped ratio.
    final ratio = limit.dailyLimit > 0
        ? limit.spentToday / limit.dailyLimit
        : (limit.spentToday > 0 ? 1.0 : 0.0);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mlg,
        AppSpacing.md,
        AppSpacing.mlg,
        AppSpacing.mlg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row: label + info + status
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        "Today's Safe Spending",
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InfoIcon(
                      content: DashboardInfo.safeSpending(limit.currency),
                    ),
                  ],
                ),
              ),
              SpendingStatusChip(status: limit.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Hero amount
          AnimatedAmount(
            amount: limit.dailyLimit,
            currency: limit.currency,
            style: theme.textTheme.displaySmall?.copyWith(
              color: colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress: spent vs safe amount
          AppProgress(
            value: ratio,
            height: AppSizes.progressLg,
            semanticLabel: "Spent today against Today's Safe Spending",
          ),
          const SizedBox(height: AppSpacing.smd),

          // Spent / left row
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Spent today',
                  amount: limit.spentToday,
                  currency: limit.currency,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: over ? 'Over by' : 'Left today',
                  amount: over ? limit.exceededToday : limit.remainingToday,
                  currency: limit.currency,
                  color: visuals.color,
                  icon: visuals.icon,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (limit.weeklyTarget > 0) ...[
            const SizedBox(height: AppSpacing.md),
            _WeekLine(limit: limit),
          ],
        ],
      ),
    );
  }
}

/// One quiet line under the daily metrics: how the week is going for this
/// budget (Monday to Sunday, clipped to the budget period).
class _WeekLine extends StatelessWidget {
  final BudgetDailyLimitEntity limit;

  const _WeekLine({required this.limit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visuals = SpendingStatusVisuals.of(context, limit.weeklyStatus);
    final ratio = limit.weeklyTarget > 0
        ? limit.weeklySpent / limit.weeklyTarget
        : 0.0;
    final spent = CurrencyFormatter.format(
      limit.weeklySpent,
      code: limit.currency,
      decimalDigits: 0,
    );
    final target = CurrencyFormatter.format(
      limit.weeklyTarget,
      code: limit.currency,
      decimalDigits: 0,
    );
    return Semantics(
      label: 'This week: $spent of $target',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'This week',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.fast,
                  ),
                  child: Text(
                    '$spent of $target',
                    key: ValueKey('$spent$target'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ratio > 1
                          ? visuals.color
                          : theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            AppProgress(
              value: ratio,
              height: AppSizes.progressThin,
              semanticLabel: 'Spent this week against the weekly share',
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color? color;
  final IconData? icon;
  final bool alignEnd;

  const _Metric({
    required this.label,
    required this.amount,
    required this.currency,
    this.color,
    this.icon,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
          child: Text(
            label,
            key: ValueKey(label),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (icon != null && !alignEnd) ...[
              Icon(icon, size: AppSizes.iconSm, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: AnimatedAmount(
                amount: amount,
                currency: currency,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                style: theme.textTheme.titleMedium?.copyWith(
                  // The status icon carries the colour signal at full
                  // strength; the figure needs a legible variant of it.
                  color: color == null
                      ? theme.colorScheme.onSurface
                      : Contrast.ensureContrast(
                          color!,
                          theme.colorScheme.surface,
                        ),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (icon != null && alignEnd) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(icon, size: AppSizes.iconSm, color: color),
            ],
          ],
        ),
      ],
    );
  }
}

/// A compact row for a budget (other than the active one) that is running
/// today, showing its own safe amount and status. Tapping opens the budget.
class OtherBudgetLimitTile extends StatelessWidget {
  final BudgetDailyLimitEntity limit;

  const OtherBudgetLimitTile({super.key, required this.limit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visuals = SpendingStatusVisuals.of(context, limit.status);
    final ratio = limit.dailyLimit > 0
        ? limit.spentToday / limit.dailyLimit
        : 0.0;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smd,
      ),
      onTap: () => context.pushUnique('/app/budgets/${limit.budgetId}'),
      child: Row(
        children: [
          IconTile(
            icon: visuals.icon,
            color: visuals.color,
            size: AppSizes.avatarSm,
            animate: true,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  limit.budgetName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                AppProgress(
                  value: ratio,
                  height: AppSizes.progressThin,
                  semanticLabel: '${limit.budgetName} spent today',
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedAmount(
                amount: limit.dailyLimit,
                currency: limit.currency,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'safe today',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown when the active budget's period does not include today.
class BudgetNotRunningCard extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onSwitch;

  const BudgetNotRunningCard({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final today = DateTime.now();
    final upcoming = today.isBefore(startDate);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: upcoming ? Icons.schedule_rounded : Icons.event_busy_rounded,
            color: colors.info,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upcoming
                      ? 'This budget starts later'
                      : 'This budget period has ended',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  upcoming
                      ? "Today's Safe Spending will appear once the period "
                            'begins.'
                      : 'Switch to a budget that is running today, or create '
                            'a new one.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    FilledButton.tonal(
                      onPressed: onSwitch,
                      child: const Text('Switch budget'),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.pushUnique('/app/budgets/create'),
                      child: const Text('New budget'),
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

/// Wraps the hero so switching budgets cross-fades to the new card, while a
/// refresh of the *same* budget only animates the numbers in place.
///
/// Give the child a key that changes with the active budget.
class SafeSpendingHeroSwitcher extends StatelessWidget {
  final Widget child;
  const SafeSpendingHeroSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.respectReducedMotion(context, AppMotion.medium);
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.standardCurve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.passthrough,
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}
