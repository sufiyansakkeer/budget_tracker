import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/app_track.dart';
import '../../../../core/widgets/status_chip.dart';
import 'budget_visuals.dart';

/// Words for where a budget is in its period, shared by the list and the
/// details screen. Day counts are calendar days, today included.
abstract final class BudgetPeriodCopy {
  static final DateFormat _day = DateFormat('d MMM');

  /// "23 days left", "Last day", "Starts 1 Nov", "Ended 31 Oct", "Archived".
  static String when(BudgetEntity budget, DateTime now) {
    switch (budget.phaseOn(now)) {
      case BudgetPhase.running:
        final left = budget.daysRemaining(now);
        return left <= 1 ? 'Last day' : '$left days left';
      case BudgetPhase.upcoming:
        return 'Starts ${_day.format(budget.startDate)}';
      case BudgetPhase.ended:
        return 'Ended ${_day.format(budget.endDate)}';
      case BudgetPhase.archived:
        return 'Archived';
    }
  }

  /// "Day 9 of 31" while running; null otherwise.
  static String? dayOf(BudgetEntity budget, DateTime now) {
    if (budget.phaseOn(now) != BudgetPhase.running) return null;
    return 'Day ${budget.daysElapsed(now)} of ${budget.totalDays}';
  }

  /// "1 – 31 Oct" (or across months, "15 Oct – 14 Nov").
  static String range(BudgetEntity budget) {
    final start = budget.startDate;
    final end = budget.endDate;
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} – ${_day.format(end)}';
    }
    return '${_day.format(start)} – ${_day.format(end)}';
  }

  /// "₹25,103 left of ₹60,000" / "₹1,200 over ₹60,000".
  static String leftLine(BudgetEntity budget) {
    final total = AppMoney.format(
      budget.monthlyAmount,
      currency: budget.currency,
    );
    final remaining = budget.remainingAmount;
    return remaining < 0
        ? '${AppMoney.format(-remaining, currency: budget.currency)} over $total'
        : '${AppMoney.format(remaining, currency: budget.currency)} left of '
              '$total';
  }
}

/// How much of a budget is used, with a tick where today falls in its
/// period. The fill is neutral; it turns critical only once the budget is
/// overspent, a fact rather than a threshold.
class BudgetUsageTrack extends StatelessWidget {
  final BudgetEntity budget;
  final DateTime now;
  final double height;

  const BudgetUsageTrack({
    super.key,
    required this.budget,
    required this.now,
    this.height = AppSizes.progressThin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = budget.monthlyAmount;
    final spent = amount - budget.remainingAmount;
    // Drawing geometry only.
    final used = amount <= 0 ? 0.0 : (spent / amount).clamp(0.0, 1.0);
    final running = budget.phaseOn(now) == BudgetPhase.running;
    final elapsed = budget.totalDays <= 0
        ? 0.0
        : budget.daysElapsed(now) / budget.totalDays;
    return AppTrack(
      value: used,
      height: height,
      color: budget.remainingAmount < 0
          ? context.tone(AppTone.critical).accent
          : theme.colorScheme.onSurfaceVariant,
      markers: [
        if (running)
          TrackMarker(position: elapsed, color: theme.colorScheme.onSurface),
      ],
      semanticLabel: 'Budget used',
    );
  }
}

/// The active budget: the one raised surface on the Budgets screen.
class ActiveBudgetCard extends StatelessWidget {
  final BudgetEntity budget;
  final DateTime now;
  final VoidCallback onTap;

  const ActiveBudgetCard({
    super.key,
    required this.budget,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = context.appTypography;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final over = budget.remainingAmount < 0;
    final dayOf = BudgetPeriodCopy.dayOf(budget, now);
    final when = BudgetPeriodCopy.when(budget, now);

    return AppSurface(
      key: ValueKey('budget_${budget.id}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mlg,
        AppSpacing.md,
        AppSpacing.mlg,
        AppSpacing.mlg,
      ),
      onTap: onTap,
      semanticLabel:
          '${budget.name}, active budget. ${BudgetPeriodCopy.leftLine(budget)}. '
          '${dayOf == null ? when : '$dayOf, $when'}. Home, Expenses and '
          'Reports follow this budget.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: BudgetVisuals.iconFor(budget.icon),
                color: BudgetVisuals.colorFor(context, budget),
                size: AppSizes.avatarSm,
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(BudgetPeriodCopy.range(budget), style: muted),
                    // Under the name, so a long name keeps its width.
                    const SizedBox(height: AppSpacing.xs),
                    const StatusChip.tone(
                      wrapLabel: true,
                      label: 'Active',
                      tone: AppTone.positive,
                      icon: Icons.check_circle_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            over ? 'Over by' : 'Left',
            style: typography.eyebrow.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppMoney(
            amount: budget.remainingAmount.abs(),
            currency: budget.currency,
            role: MoneyRole.display,
            color: over ? context.tone(AppTone.critical).accent : null,
          ),
          Text(
            'of ${AppMoney.format(budget.monthlyAmount, currency: budget.currency)}',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.smd),
          BudgetUsageTrack(budget: budget, now: now),
          const SizedBox(height: AppSpacing.sm),
          Text([?dayOf, when].join(' · '), style: muted),
          const SizedBox(height: AppSpacing.smd),
          Row(
            children: [
              Icon(
                Icons.sync_alt_rounded,
                size: AppSizes.iconSm,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Home, Expenses and Reports follow this budget',
                  style: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Any other budget: one compact row with what is left and, while it
/// runs, a thin bar with a tick for today.
class BudgetRow extends StatelessWidget {
  final BudgetEntity budget;
  final DateTime now;
  final VoidCallback onTap;

  const BudgetRow({
    super.key,
    required this.budget,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final phase = budget.phaseOn(now);
    final over = budget.remainingAmount < 0;
    final when = BudgetPeriodCopy.when(budget, now);
    final detail = '${BudgetPeriodCopy.range(budget)} · $when';

    return Opacity(
      opacity: phase == BudgetPhase.archived ? 0.75 : 1,
      child: AppListRow(
        key: ValueKey('budget_${budget.id}'),
        leading: IconTile(
          icon: BudgetVisuals.iconFor(budget.icon),
          color: BudgetVisuals.colorFor(context, budget),
          size: AppSizes.avatarSm,
        ),
        title: budget.name,
        subtitleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(detail, style: muted, maxLines: 2),
            if (phase == BudgetPhase.running) ...[
              const SizedBox(height: AppSpacing.xs),
              BudgetUsageTrack(budget: budget, now: now, height: 3),
            ],
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppMoney(
              amount: budget.remainingAmount.abs(),
              currency: budget.currency,
              textAlign: TextAlign.end,
              color: over ? context.tone(AppTone.critical).accent : null,
            ),
            Text(over ? 'over' : 'left', style: muted),
          ],
        ),
        semanticLabel:
            '${budget.name}, ${BudgetPeriodCopy.leftLine(budget)}, $detail',
        onTap: onTap,
      ),
    );
  }
}
