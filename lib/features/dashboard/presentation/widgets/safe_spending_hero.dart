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
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import 'dashboard_info.dart';
import 'safe_to_spend_copy.dart';
import 'spending_status.dart';
import '../../../../core/navigation/push_unique.dart';

/// The dashboard's primary element: how much the user can still spend today
/// in the active budget, what they have spent, and whether they are on track.
///
/// Renders [BudgetDailyLimitEntity.safeToSpend] (bills, money kept aside and
/// the savings goal deducted) when present; an entry without it gets the
/// legacy daily/weekly rendering. The widget only presents figures.
class SafeSpendingHero extends StatelessWidget {
  final BudgetDailyLimitEntity limit;

  const SafeSpendingHero({super.key, required this.limit});

  @override
  Widget build(BuildContext context) {
    final safeToSpend = limit.safeToSpend;
    if (safeToSpend != null) return _SafeToSpendHero(entity: safeToSpend);
    return _LegacyHero(limit: limit);
  }
}

/// The engine-driven hero: today's amount (floored to the digits shown),
/// status, discretionary spending today, a caption for bill payments and one
/// explanation line. No week line: a second, bill-blind formula would
/// contradict the daily figure.
class _SafeToSpendHero extends StatelessWidget {
  final SafeToSpendEntity entity;

  const _SafeToSpendHero({required this.entity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final e = entity;
    final visuals = SafeToSpendStatusVisuals.of(context, e.status);
    final daily = CurrencyFormatter.floorForDisplay(
      e.dailySafeToSpend,
      code: e.currency,
    );
    final left = CurrencyFormatter.floorForDisplay(
      e.remainingToday,
      code: e.currency,
    );
    final over = e.overToday > 0;
    final ratio = e.dailySafeToSpend > 0
        ? e.todayDiscretionary / e.dailySafeToSpend
        : (e.todayDiscretionary > 0 ? 1.0 : 0.0);
    final explanation = SafeToSpendCopy.heroExplanation(e);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mlg,
        AppSpacing.md,
        AppSpacing.mlg,
        AppSpacing.mlg,
      ),
      // One node for the figures, read as a unit; the info button stays a
      // separate, focusable child.
      child: Semantics(
        container: true,
        label: SafeToSpendCopy.heroSemantics(e),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and status chip share a line when they fit; on a narrow
            // screen or with large text the chip moves below the title
            // instead of squeezing the info button (no overflow, nothing
            // truncated).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: AppSpacing.xxs,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ExcludeSemantics(
                        child: Text(
                          "Today's Safe Spending",
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    InfoIcon(content: DashboardInfo.safeSpending(e.currency)),
                  ],
                ),
                ExcludeSemantics(
                  child: SafeToSpendStatusChip(
                    status: e.status,
                    wrapLabel: true,
                  ),
                ),
              ],
            ),
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  AnimatedAmount(
                    amount: daily.amount,
                    currency: e.currency,
                    decimalDigits: daily.decimalDigits,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    SafeToSpendCopy.heroSubline(e),
                    style: secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppProgress(value: ratio, height: AppSizes.progressLg),
                  const SizedBox(height: AppSpacing.smd),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Spent today',
                          amount: e.todayDiscretionary,
                          currency: e.currency,
                          decimalDigits: SafeToSpendCopy.digitsFor(
                            e.todayDiscretionary,
                            e.currency,
                          ),
                        ),
                      ),
                      Expanded(
                        // "Over by" is always shown as an error, whatever
                        // the chip says.
                        child: over
                            ? _Metric(
                                label: 'Over by',
                                amount: e.overToday,
                                currency: e.currency,
                                decimalDigits: SafeToSpendCopy.digitsFor(
                                  e.overToday,
                                  e.currency,
                                ),
                                color: context.appColors.error,
                                icon: Icons.error_rounded,
                                alignEnd: true,
                              )
                            : _Metric(
                                label: 'Left today',
                                amount: left.amount,
                                currency: e.currency,
                                decimalDigits: left.decimalDigits,
                                color: visuals.color,
                                icon: visuals.icon,
                                alignEnd: true,
                              ),
                      ),
                    ],
                  ),
                  if (e.committedSpentToday > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      SafeToSpendCopy.billPaymentsToday(e),
                      style: secondary,
                    ),
                  ],
                  if (explanation != null) ...[
                    const SizedBox(height: AppSpacing.smd),
                    _ExplanationLine(text: explanation, color: visuals.color),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
          Icon(Icons.info_outline_rounded, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The original hero for an entry without a safe-to-spend entity: daily
/// figures plus the weekly line.
class _LegacyHero extends StatelessWidget {
  final BudgetDailyLimitEntity limit;

  const _LegacyHero({required this.limit});

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
  final int decimalDigits;
  final Color? color;
  final IconData? icon;
  final bool alignEnd;

  const _Metric({
    required this.label,
    required this.amount,
    required this.currency,
    this.decimalDigits = 0,
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
                decimalDigits: decimalDigits,
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
///
/// Read by screen readers as one button: "{name}: {amount} safe today,
/// {status}" — the status is otherwise carried by the icon alone.
class OtherBudgetLimitTile extends StatelessWidget {
  final BudgetDailyLimitEntity limit;

  const OtherBudgetLimitTile({super.key, required this.limit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeToSpend = limit.safeToSpend;
    final Color color;
    final IconData icon;
    final String statusLabel;
    if (safeToSpend != null) {
      final visuals = SafeToSpendStatusVisuals.of(context, safeToSpend.status);
      (color, icon, statusLabel) = (visuals.color, visuals.icon, visuals.label);
    } else {
      final visuals = SpendingStatusVisuals.of(context, limit.status);
      (color, icon, statusLabel) = (visuals.color, visuals.icon, visuals.label);
    }
    // Engine amounts are floored to the digits shown; legacy ones keep the
    // whole-unit rendering they always had.
    final daily = safeToSpend != null
        ? CurrencyFormatter.floorForDisplay(
            limit.dailyLimit,
            code: limit.currency,
          )
        : (amount: limit.dailyLimit, decimalDigits: 0);
    final ratio = limit.dailyLimit > 0
        ? limit.spentToday / limit.dailyLimit
        : 0.0;
    final amountText = CurrencyFormatter.format(
      daily.amount,
      code: limit.currency,
      decimalDigits: daily.decimalDigits,
    );
    void open() => context.pushUnique('/app/budgets/${limit.budgetId}');

    return Semantics(
      button: true,
      label: '${limit.budgetName}: $amountText safe today, $statusLabel',
      onTap: open,
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        onTap: open,
        child: Row(
          children: [
            IconTile(
              icon: icon,
              color: color,
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
                  amount: daily.amount,
                  currency: limit.currency,
                  decimalDigits: daily.decimalDigits,
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
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chip != null) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: chip,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.sm, children: actions),
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
