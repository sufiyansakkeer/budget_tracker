import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/app_track.dart';
import '../../../../core/widgets/status_chip.dart';
import '../start_next_period.dart';
import 'budget_visuals.dart';

/// Words for where a budget is in its period, shared by the list and the
/// details screen. Day counts are calendar days, today included.
abstract final class BudgetPeriodCopy {
  static final DateFormat _day = DateFormat('d MMM');

  /// "23 days left", "Last day", "Starts 1 Nov", "Ended 31 Oct", "Archived".
  /// [withToday] says that today is one of the days left, for beside
  /// [dayOf], which counts today too ("23 days left, incl. today", with a
  /// no-break space so the qualifier never splits).
  static String when(
    BudgetEntity budget,
    DateTime now, {
    bool withToday = false,
  }) {
    switch (budget.phaseOn(now)) {
      case BudgetPhase.running:
        final left = budget.daysRemaining(now);
        if (left <= 1) return 'Last day';
        return '$left days left${withToday ? ', incl.\u00A0today' : ''}';
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

/// Where a budget is in its period, under its name. The active budget says
/// so and, unless it runs today, where it is ("Active · Ended"), so an ended
/// active budget never reads as a healthy one.
class BudgetStatusChip extends StatelessWidget {
  final BudgetEntity budget;
  final bool isActive;
  final DateTime now;

  const BudgetStatusChip({
    super.key,
    required this.budget,
    required this.isActive,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final phase = budget.phaseOn(now);
    final (label, tone, icon) = switch (phase) {
      BudgetPhase.running when isActive => (
        'Active',
        AppTone.positive,
        Icons.check_circle_rounded,
      ),
      BudgetPhase.running => (
        'Not active',
        AppTone.neutral,
        Icons.radio_button_off_rounded,
      ),
      BudgetPhase.upcoming => (
        'Upcoming',
        AppTone.info,
        Icons.schedule_rounded,
      ),
      // Ended while Home still follows it: something to act on.
      BudgetPhase.ended => (
        'Ended',
        isActive ? AppTone.caution : AppTone.neutral,
        Icons.event_busy_rounded,
      ),
      BudgetPhase.archived => (
        'Archived',
        AppTone.neutral,
        Icons.archive_rounded,
      ),
    };
    return StatusChip.tone(
      wrapLabel: true,
      label: isActive && phase != BudgetPhase.running
          ? 'Active · $label'
          : label,
      tone: tone,
      icon: icon,
    );
  }
}

/// A budget whose period is over, with "Start next period". For the active
/// budget it is a caution: Home has no daily figure until a budget runs.
class EndedBudgetNotice extends StatelessWidget {
  final BudgetEntity budget;
  final bool isActive;

  const EndedBudgetNotice({
    super.key,
    required this.budget,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    const carryOn =
        'Start the next period to carry on with the same amount and '
        'set-asides.';
    return AppNotice(
      tone: isActive ? AppTone.caution : AppTone.neutral,
      icon: Icons.event_busy_rounded,
      title:
          '${budget.name} ended ${BudgetPeriodCopy._day.format(budget.endDate)}',
      message: isActive
          ? "Home has no Today's Safe Spending until a budget runs today. "
                '$carryOn'
          : carryOn,
      action: TextButton(
        onPressed: () => StartNextPeriod.open(context, budget.id),
        child: const Text('Start next period'),
      ),
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
    final when = BudgetPeriodCopy.when(budget, now, withToday: true);

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
                    BudgetStatusChip(budget: budget, isActive: true, now: now),
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
