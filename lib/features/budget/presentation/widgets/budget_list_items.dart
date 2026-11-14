import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/app_track.dart';
import '../../../../core/widgets/status_chip.dart';
import '../start_next_period.dart';
import 'budget_visuals.dart';
import '../../../dashboard/presentation/widgets/target_ring.dart';
import '../../../dashboard/presentation/widgets/safe_to_spend_copy.dart';
import '../../domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/constants/app_copy.dart';

/// Words for where a budget is in its period, shared by the list and the
/// details screen. Day counts are calendar days, today included.
abstract final class BudgetPeriodCopy {
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
        return 'Starts ${AppDates.day(budget.startDate, now: now)}';
      case BudgetPhase.ended:
        return 'Ended ${AppDates.day(budget.endDate, now: now)}';
      case BudgetPhase.archived:
        return 'Archived';
    }
  }

  /// "Day 9 of 31" while running; null otherwise.
  static String? dayOf(BudgetEntity budget, DateTime now) {
    if (budget.phaseOn(now) != BudgetPhase.running) return null;
    return 'Day ${budget.daysElapsed(now)} of ${budget.totalDays}';
  }

  /// "1 – 31 Oct" (or across months, "15 Oct – 14 Nov"), with the year
  /// when the period isn't in the current year ("1 – 31 Oct 2025").
  static String range(BudgetEntity budget, {DateTime? now}) =>
      AppDates.span(budget.startDate, budget.endDate, now: now);

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
    final share = amount <= 0 ? 0.0 : spent / amount;
    // Drawing geometry only: the screen reader hears the real share, so
    // an overspent budget reads "125%", not "100%".
    final used = share.clamp(0.0, 1.0);
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
      semanticValue: '${(share < 0 ? 0 : share * 100).round()}%',
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
        AppTerms.notStarted,
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
      title: '${budget.name} ended ${AppDates.day(budget.endDate)}',
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

/// Any other budget: one compact row with what is left and, while it
/// runs, a thin bar with a tick for today.
class BudgetRow extends StatelessWidget {
  final BudgetEntity budget;
  final DateTime now;
  final VoidCallback onTap;

  /// Its figures today, when running: the row then leads with a small ring
  /// of its day and says its daily target (blueprint).
  final SafeToSpendEntity? figures;

  /// The active budget: an "Active" chip after its name (blueprint).
  final bool isActive;

  const BudgetRow({
    super.key,
    required this.budget,
    required this.now,
    required this.onTap,
    this.figures,
    this.isActive = false,
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
    final f = figures;
    final daily = f != null && f.isRunning ? f : null;
    final detail = daily == null
        ? '${BudgetPeriodCopy.range(budget)} · $when'
        : '${SafeToSpendCopy.safeAmount(daily.dailySafeToSpend, daily.currency)} '
              'a day · ${daily.overToday > 0 ? 'over today' : when}';
    // An archived budget steps back in the muted text colour, which keeps
    // its contrast (a faded row did not).
    final archived = phase == BudgetPhase.archived;
    final quiet = archived ? theme.colorScheme.onSurfaceVariant : null;

    return AppListRow(
      key: ValueKey('budget_${budget.id}'),
      leading: daily == null
          ? IconTile(
              icon: BudgetVisuals.iconFor(budget.icon),
              color: BudgetVisuals.colorFor(context, budget),
              size: AppSizes.avatarSm,
            )
          : SizedBox.square(
              dimension: AppSizes.avatarSm,
              child: Center(
                child: MiniTargetRing(
                  spent: daily.todayDiscretionary,
                  target: daily.dailySafeToSpend,
                  size: 36,
                ),
              ),
            ),
      title: budget.name,
      titleColor: quiet,
      titleTrailing: isActive
          ? DecoratedBox(
              key: const ValueKey('activeBudgetChip'),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: AppSpacing.borderRadiusFull,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                child: Text(
                  // Unless it runs today, where it is ("Active · Ended").
                  phase == BudgetPhase.running
                      ? 'Active'
                      : 'Active · ${switch (phase) {
                          BudgetPhase.upcoming => AppTerms.notStarted,
                          BudgetPhase.ended => 'Ended',
                          _ => 'Archived',
                        }}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            )
          : null,
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
            color: over ? context.tone(AppTone.critical).accent : quiet,
          ),
          Text(over ? 'over' : 'left', style: muted),
        ],
      ),
      semanticLabel:
          '${budget.name}${isActive ? ', active' : ''}, '
          '${BudgetPeriodCopy.leftLine(budget)}, $detail',
      onTap: onTap,
    );
  }
}
