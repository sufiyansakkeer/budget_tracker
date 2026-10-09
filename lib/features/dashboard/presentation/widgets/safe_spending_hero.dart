import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_metric.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/app_track.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import 'dashboard_info.dart';
import 'safe_to_spend_copy.dart';
import 'spending_status.dart';
import '../../../../core/widgets/app_animated_size.dart';

/// The Home screen's one raised surface: Today's Safe Spending.
///
/// It tells the figure's story top to bottom, all from the engine's
/// [SafeToSpendEntity]: the amount (floored, the largest number in the app),
/// its status as a word and an icon, today's spending against it, one line
/// on why it is what it is, then the budget behind it: money used against a
/// tick for today's place in the period, what is left and how many days.
/// "How it's worked out" ([onShowWorking]) opens the full working.
///
/// The widget only presents figures; it never computes money.
class SafeSpendingHero extends StatelessWidget {
  final BudgetDailyLimitEntity limit;

  /// Opens the breakdown; the action is hidden when null.
  final VoidCallback? onShowWorking;

  const SafeSpendingHero({super.key, required this.limit, this.onShowWorking});

  @override
  Widget build(BuildContext context) {
    final safeToSpend = limit.safeToSpend;
    // Every running budget's limit carries the engine's result; without it
    // there is no figure to show.
    if (safeToSpend == null) return const _HeroUnavailable();
    return _SafeToSpendHero(
      entity: safeToSpend,
      budgetUtilization: limit.budgetUtilization,
      onShowWorking: onShowWorking,
    );
  }
}

class _SafeToSpendHero extends StatelessWidget {
  final SafeToSpendEntity entity;

  /// The domain's spent ÷ amount ratio for this budget.
  final double budgetUtilization;
  final VoidCallback? onShowWorking;

  const _SafeToSpendHero({
    required this.entity,
    required this.budgetUtilization,
    this.onShowWorking,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final e = entity;
    final visuals = SafeToSpendStatusVisuals.of(context, e.status);
    final tone = context.tone(visuals.tone);
    final over = e.overToday > 0;
    // How much of today's amount is used: drawing geometry only.
    final todayUsed = e.dailySafeToSpend > 0
        ? e.todayDiscretionary / e.dailySafeToSpend
        : (e.todayDiscretionary > 0 ? 1.0 : 0.0);
    final elapsed = e.totalDays > 0 ? e.daysPassed / e.totalDays : 0.0;
    final explanation = SafeToSpendCopy.heroExplanation(e);
    final spread = SafeToSpendCopy.overSpread(e);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    final semantics = StringBuffer(SafeToSpendCopy.heroSemantics(e));
    if (spread != null) semantics.write(' $spread');
    semantics.write(
      ' ${SafeToSpendCopy.budgetLeftLine(e)}, '
      '${SafeToSpendCopy.daysLeft(e).toLowerCase()}.',
    );

    return AppSurface(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mlg,
        AppSpacing.md,
        AppSpacing.mlg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // One node for the figures, read as a unit; the info button stays
          // a separate, focusable child.
          Semantics(
            container: true,
            label: semantics.toString(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          "Today's Safe Spending",
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    InfoIcon(content: DashboardInfo.safeSpending(e.currency)),
                  ],
                ),
                ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppMoney(
                        amount: e.dailySafeToSpend,
                        currency: e.currency,
                        role: MoneyRole.hero,
                        floored: true,
                        split: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SafeToSpendStatusChip(status: e.status, wrapLabel: true),
                      const SizedBox(height: AppSpacing.mlg),
                      AppTrack(value: todayUsed, color: tone.accent),
                      const SizedBox(height: AppSpacing.smd),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppMetric(
                              label: 'Spent today',
                              value: AppMoney(
                                amount: e.todayDiscretionary,
                                currency: e.currency,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: over
                                ? AppMetric(
                                    label: 'Over by',
                                    alignEnd: true,
                                    value: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: AppMoney(
                                            amount: e.overToday,
                                            currency: e.currency,
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        // Over today's amount is recoverable
                                        // (tomorrow absorbs it), so it is
                                        // caution, never the red kept for
                                        // money already gone.
                                        Icon(
                                          Icons.error_rounded,
                                          size: AppSizes.iconSm,
                                          color: context
                                              .tone(AppTone.caution)
                                              .accent,
                                        ),
                                      ],
                                    ),
                                  )
                                : AppMetric(
                                    label: 'Left today',
                                    alignEnd: true,
                                    value: AppMoney(
                                      amount: e.remainingToday,
                                      currency: e.currency,
                                      floored: true,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      if (e.committedSpentToday > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          SafeToSpendCopy.billPaymentsToday(e),
                          style: muted,
                        ),
                      ],
                      if (spread != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(spread, style: muted),
                      ],
                      if (explanation != null) ...[
                        const SizedBox(height: AppSpacing.smd),
                        _ExplanationLine(text: explanation, color: tone.accent),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Divider(color: colorScheme.outlineVariant),
                      const SizedBox(height: AppSpacing.smd),
                      _BudgetLine(
                        entity: e,
                        utilization: budgetUtilization,
                        elapsed: elapsed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onShowWorking != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onShowWorking,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text("How it's worked out")),
                    Icon(Icons.chevron_right_rounded, size: AppSizes.iconMd),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// The budget behind today's amount: money used (the fill) against today's
/// place in the period (the tick), what is left and the days to go. A fill
/// past the tick means spending is running ahead of time; the status chip
/// above says whether that matters.
class _BudgetLine extends StatelessWidget {
  final SafeToSpendEntity entity;
  final double utilization;
  final double elapsed;

  const _BudgetLine({
    required this.entity,
    required this.utilization,
    required this.elapsed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final e = entity;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Side by side when they fit; at large text the days drop under the
        // amount instead of squeezing it.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xxs,
          children: [
            Text(
              SafeToSpendCopy.budgetLeftLine(e),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
            Text(SafeToSpendCopy.daysLeft(e), style: muted),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTrack(
          value: utilization,
          color: e.availableBalance < 0
              ? context.tone(AppTone.critical).accent
              : colorScheme.onSurfaceVariant,
          height: AppSizes.progressThin,
          markers: [
            TrackMarker(position: elapsed, color: colorScheme.onSurface),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(SafeToSpendCopy.dayOfPeriod(e), style: muted),
      ],
    );
  }
}

/// The hero's single "why" sentence, with the status icon.
class _ExplanationLine extends StatelessWidget {
  final String text;
  final Color color;

  const _ExplanationLine({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
      child: Row(
        key: ValueKey(text),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(
              Icons.info_outline_rounded,
              size: AppSizes.iconSm,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
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
      label:
          '${limit.budgetName}: $amountText safe today'
          '${status == null ? '' : ', ${status.label}'}',
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
class SafeSpendingNotRunningCard extends StatelessWidget {
  final SafeToSpendEntity safeToSpend;
  final VoidCallback onSwitch;

  const SafeSpendingNotRunningCard({
    super.key,
    required this.safeToSpend,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final e = safeToSpend;
    final visuals = SafeToSpendStatusVisuals.of(context, e.status);
    return _HeroMessageCard(
      icon: visuals.icon,
      color: visuals.color,
      chip: SafeToSpendStatusChip(status: e.status),
      title: SafeToSpendCopy.notRunningTitle(e),
      message: SafeToSpendCopy.notRunningMessage(e),
      actions: [
        FilledButton.tonal(
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
        FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
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
