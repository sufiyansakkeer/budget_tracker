import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import '../../../budget/presentation/start_next_period.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import 'safe_to_spend_copy.dart';
import 'spending_status.dart';
import 'target_ring.dart';
import '../../../../core/widgets/app_animated_size.dart';

/// The top of Today: Today's Safe Spending.
///
/// Today's amount as a ring ([TargetRing]): spending runs round it, and the
/// middle says what is left today (or how much over, in caution) out of
/// the day's amount. Under it: the status as a word and an icon, and one
/// line on why the amount is what it is. "How it's worked out"
/// ([onShowWorking]) opens the full working. The budget as a whole lives on
/// the Budget tab.
///
/// The widget only presents figures; it never computes money.
class SafeSpendingHero extends StatelessWidget {
  final BudgetDailyLimitEntity limit;

  /// Opens the breakdown (a tap on the ring); nothing when null.
  final VoidCallback? onShowWorking;

  /// Today's expenses in order, one arc each on the ring.
  final List<double>? segments;

  const SafeSpendingHero({
    super.key,
    required this.limit,
    this.onShowWorking,
    this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final safeToSpend = limit.safeToSpend;
    // Every running budget's limit carries the engine's result; without it
    // there is no figure to show.
    if (safeToSpend == null) return const _HeroUnavailable();
    return _SafeToSpendHero(
      entity: safeToSpend,
      segments: segments,
      onShowWorking: onShowWorking,
    );
  }
}

class _SafeToSpendHero extends StatelessWidget {
  final SafeToSpendEntity entity;
  final List<double>? segments;
  final VoidCallback? onShowWorking;

  const _SafeToSpendHero({
    required this.entity,
    this.segments,
    this.onShowWorking,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final e = entity;
    final over = e.overToday > 0;
    // Over today's target is recoverable (tomorrow absorbs it), so the
    // middle says so in caution, never the red kept for money already gone.
    final caution = context.tone(AppTone.caution).accent;
    final line = SafeToSpendCopy.heroLine(e);
    final spread = SafeToSpendCopy.overSpread(e);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontSize: 13,
    );

    final semantics = StringBuffer(SafeToSpendCopy.heroSemantics(e));
    if (spread != null) semantics.write(' $spread');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TargetRing(
            spent: e.todayDiscretionary,
            target: e.dailySafeToSpend,
            segments: segments,
            onTap: onShowWorking,
            semanticsLabel: CurrencyFormatter.forSpeech(semantics.toString()),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  over ? 'Over today' : 'Left today',
                  // Blueprint .lab: 13/600.
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: over ? caution : colorScheme.onSurfaceVariant,
                  ),
                ),
                AppMoney(
                  amount: over ? e.overToday : e.remainingToday,
                  currency: e.currency,
                  role: MoneyRole.hero,
                  floored: !over,
                  split: true,
                  color: over ? caution : null,
                ),
                Text(
                  'of ${SafeToSpendCopy.safeAmount(e.dailySafeToSpend, e.currency)} target',
                  style: muted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Everything below is in the ring's label already.
        ExcludeSemantics(
          child: Column(
            children: [
              SafeToSpendStatusChip(status: e.status, wrapLabel: true),
              for (final text in [
                if (e.committedSpentToday > 0)
                  SafeToSpendCopy.billPaymentsToday(e),
                ?spread,
                ?line,
              ]) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Text(text, style: muted, textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A budget other than the active one that is running today: its own safe
/// amount and status, as one row. Tapping opens the budget.
///
/// Read by screen readers as one button: "{name}: {amount} safe today,
/// {status}".
class OtherBudgetLimitTile extends StatelessWidget {
  final BudgetDailyLimitEntity limit;

  const OtherBudgetLimitTile({super.key, required this.limit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeToSpend = limit.safeToSpend;
    final status = safeToSpend == null
        ? null
        : SafeToSpendStatusVisuals.of(context, safeToSpend.status);
    final accent = status?.color ?? theme.colorScheme.onSurfaceVariant;
    final daily = CurrencyFormatter.floorForDisplay(
      limit.dailyLimit,
      code: limit.currency,
    );
    final amountText = CurrencyFormatter.format(
      daily.amount,
      code: limit.currency,
      decimalDigits: daily.decimalDigits,
    );
    void open() => context.pushUnique('/app/budgets/${limit.budgetId}');

    return Semantics(
      button: true,
      label: CurrencyFormatter.forSpeech(
        '${limit.budgetName}: $amountText safe today'
        '${status == null ? '' : ', ${status.label}'}',
      ),
      onTap: open,
      excludeSemantics: true,
      child: InkWell(
        onTap: open,
        borderRadius: AppSpacing.borderRadiusSm,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.listRowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                IconTile(
                  icon: status?.icon ?? Icons.account_balance_wallet_rounded,
                  color: accent,
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
                      if (status != null)
                        Text(
                          status.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppMoney(
                      amount: limit.dailyLimit,
                      currency: limit.currency,
                      floored: true,
                      textAlign: TextAlign.end,
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
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the hero when the active budget's period does not
/// include today, from the engine's not-started / ended result: when it
/// starts and what it sets aside, or how it ended. There is no daily figure.
/// An ended budget leads with "Start next period".
class SafeSpendingNotRunningCard extends StatelessWidget {
  final SafeToSpendEntity safeToSpend;
  final VoidCallback onSwitch;

  const SafeSpendingNotRunningCard({
    super.key,
    required this.safeToSpend,
    required this.onSwitch,
  });

  /// The next period's daily target if it starts now: the same amount and
  /// set-asides over its days, before bills (blueprint: "Start next period
  /// at ₹1,935 a day").
  static double nextPeriodDaily(SafeToSpendEntity e) {
    final next = StartNextPeriod.datesAfterPeriod(e.startDate, e.endDate);
    final days = next.end.difference(next.start).inDays + 1;
    final free =
        e.budgetAmount - (e.reservedAmount ?? 0) - (e.savingsTarget ?? 0);
    return days < 1 || free <= 0 ? 0 : free / days;
  }

  @override
  Widget build(BuildContext context) {
    final e = safeToSpend;
    if (e.status == SafeToSpendStatus.periodEnded) {
      return _EndedCard(e: e, onSwitch: onSwitch);
    }
    final visuals = SafeToSpendStatusVisuals.of(context, e.status);
    return _HeroMessageCard(
      icon: visuals.icon,
      color: visuals.color,
      chip: SafeToSpendStatusChip(status: e.status),
      title: SafeToSpendCopy.notRunningTitle(e),
      message: SafeToSpendCopy.notRunningMessage(e),
      actions: [
        FilledButton.tonal(
          style: AppTheme.tonal(context),
          onPressed: onSwitch,
          child: const Text('Switch budget'),
        ),
        TextButton(
          onPressed: () => context.pushUnique('/app/budgets/create'),
          child: const Text('New budget'),
        ),
      ],
    );
  }
}

/// The active budget has ended (blueprint): a closed ring with the result
/// inside, the next period at the daily target it would start at, and the
/// other ways on.
class _EndedCard extends StatelessWidget {
  final SafeToSpendEntity e;
  final VoidCallback onSwitch;

  const _EndedCard({required this.e, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = e.availableBalance < 0;
    final result = over
        ? '${SafeToSpendCopy.amount(-e.availableBalance, e.currency)} over'
        : '${SafeToSpendCopy.amount(e.availableBalance, e.currency)} left';
    final ended = 'Ended ${SafeToSpendCopy.date(e.endDate)}';
    final daily = SafeSpendingNotRunningCard.nextPeriodDaily(e);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TargetRing(
            spent: 1,
            target: 1,
            diameter: 180,
            stroke: 14,
            semanticsLabel: '$ended, $result',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ended,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  result,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: over ? context.tone(AppTone.critical).accent : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => StartNextPeriod.open(context, e.budgetId),
          child: Text(
            daily > 0
                ? 'Start next period at '
                      '${SafeToSpendCopy.safeAmount(daily, e.currency)} a day'
                : 'Start next period',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onSwitch,
                child: const Text('Switch budget'),
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.pushUnique('/app/budgets/create'),
                child: const Text('New budget'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shown in place of the hero when the active budget is running but its
/// figures could not be computed. Never claims the period has ended.
class SafeSpendingUnavailableCard extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onSwitch;

  const SafeSpendingUnavailableCard({
    super.key,
    required this.onRetry,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return _HeroMessageCard(
      icon: Icons.cloud_off_rounded,
      color: context.appColors.warning,
      title: "Today's Safe Spending isn't available",
      message:
          "This budget's figures couldn't be calculated right now. Try "
          'again, or switch to another budget.',
      actions: [
        FilledButton.tonal(
          style: AppTheme.tonal(context),
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
        TextButton(onPressed: onSwitch, child: const Text('Switch budget')),
      ],
    );
  }
}

/// Shown in place of the hero when the active budget is archived. Archived
/// budgets get no daily figure (nothing is worked out for them), so this
/// points to switching budget or the budget's details (to restore it)
/// rather than to a retry.
class SafeSpendingArchivedCard extends StatelessWidget {
  final VoidCallback onSwitch;
  final VoidCallback? onOpenBudget;

  const SafeSpendingArchivedCard({
    super.key,
    required this.onSwitch,
    this.onOpenBudget,
  });

  @override
  Widget build(BuildContext context) {
    return _HeroMessageCard(
      icon: Icons.archive_outlined,
      color: context.appColors.primary,
      title: 'This budget is archived',
      message:
          "Today's Safe Spending is only worked out for budgets in use. "
          'Switch to another budget, or restore this one from its details.',
      actions: [
        FilledButton.tonal(
          style: AppTheme.tonal(context),
          onPressed: onSwitch,
          child: const Text('Switch budget'),
        ),
        if (onOpenBudget != null)
          TextButton(
            onPressed: onOpenBudget,
            child: const Text('Budget details'),
          ),
      ],
    );
  }
}

/// The hero's place when a daily limit arrives without the engine's result,
/// which a running budget never does.
class _HeroUnavailable extends StatelessWidget {
  const _HeroUnavailable();

  @override
  Widget build(BuildContext context) {
    return _HeroMessageCard(
      icon: Icons.cloud_off_rounded,
      color: context.appColors.warning,
      title: "Today's Safe Spending isn't available",
      message: "This budget's figures couldn't be calculated right now.",
      actions: const [],
    );
  }
}

class _HeroMessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Widget? chip;
  final String title;
  final String message;
  final List<Widget> actions;

  const _HeroMessageCard({
    required this.icon,
    required this.color,
    this.chip,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.mlg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, color: color),
              if (chip != null) ...[
                const SizedBox(width: AppSpacing.smd),
                Flexible(child: chip!),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
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
    return AppAnimatedSize(
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
          children: [...previous, ?current],
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
