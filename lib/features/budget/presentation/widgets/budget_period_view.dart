import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../dashboard/presentation/widgets/safe_to_spend_copy.dart';
import '../../../dashboard/presentation/widgets/target_ring.dart';
import '../../domain/entities/safe_to_spend/safe_to_spend_entity.dart';

/// Another budget for the "Other budgets" list: its figures when they could
/// be worked out.
typedef OtherBudget = (BudgetEntity budget, SafeToSpendEntity? figures);

/// The Budget tab's period view (blueprint): what is left in the budget
/// against time, the forecast in one sentence, where the whole amount is
/// (the money map), its pots, the one lever ("Change your daily target")
/// and the other budgets.
///
/// Presents the engine's [SafeToSpendEntity]; computes nothing but shares
/// and proportions.
class BudgetPeriodView extends StatelessWidget {
  final BudgetEntity budget;
  final SafeToSpendEntity e;
  final int expenseCount;
  final List<OtherBudget> others;

  /// The title row (name, switch, menu) on the tab; null under an app bar.
  final Widget? title;
  final VoidCallback onShowWorking;
  final VoidCallback onChangeTarget;
  final VoidCallback onOpenBills;
  final VoidCallback onOpenSpent;
  final VoidCallback onAllBudgets;
  final ValueChanged<BudgetEntity> onOpenOther;

  /// Notes and notices that stay with the budget, after the lever.
  final List<Widget> footer;

  const BudgetPeriodView({
    super.key,
    required this.budget,
    required this.e,
    required this.expenseCount,
    required this.others,
    this.title,
    required this.onShowWorking,
    required this.onChangeTarget,
    required this.onOpenBills,
    required this.onOpenSpent,
    required this.onAllBudgets,
    required this.onOpenOther,
    this.footer = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final over = e.availableBalance < 0;
    final used = e.budgetAmount > 0 ? e.periodSpent / e.budgetAmount : 0.0;
    final elapsed = e.totalDays > 0 ? e.daysPassed / e.totalDays : 0.0;
    final toGo = e.totalDays > 0
        ? ((e.totalDays - e.daysPassed) / e.totalDays * 100).round()
        : 0;
    final total = AppMoney.format(e.budgetAmount, currency: e.currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?title,
        Text(
          '${AppDates.range(e.startDate, e.endDate)} · '
          'day ${e.daysPassed} of ${e.totalDays}',
          style: muted,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          over ? 'Over this budget by' : 'Left in this budget',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        AppMoney(
          amount: e.availableBalance.abs(),
          currency: e.currency,
          // Blueprint .amt: the 48 hero figure, split.
          role: MoneyRole.hero,
          split: true,
          color: over ? context.tone(AppTone.critical).accent : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'of $total · ${(used * 100).floor().clamp(0, 999)}% used with '
          '$toGo% of the period to go',
          style: muted?.copyWith(fontSize: 13),
        ),
        const SizedBox(height: AppSpacing.smd),
        _UsedTrack(used: used, elapsed: elapsed),
        const SizedBox(height: AppSpacing.smd),
        _ForecastNote(e: e),
        const SizedBox(height: AppSpacing.md),
        _MapCard(e: e, onShowWorking: onShowWorking, onOpenSpent: onOpenSpent),
        _Heading('Pots'),
        _Pots(
          e: e,
          expenseCount: expenseCount,
          onShowWorking: onShowWorking,
          onChangeTarget: onChangeTarget,
          onOpenBills: onOpenBills,
          onOpenSpent: onOpenSpent,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonalIcon(
          onPressed: onChangeTarget,
          style: AppTheme.tonal(context).merge(
            FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Change your daily target'),
        ),
        ...footer,
        _Heading(
          'Other budgets',
          action: TextButton(
            onPressed: onAllBudgets,
            child: const Text('All budgets'),
          ),
        ),
        if (others.isEmpty)
          Text('No other budget is running or coming up.', style: muted)
        else
          AppGroupedList(
            dividerIndent: AppSizes.avatarSm + AppSpacing.md,
            children: [
              for (final other in others)
                _OtherRow(other: other, onTap: () => onOpenOther(other.$1)),
            ],
          ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  final Widget? action;

  const _Heading(this.text, {this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Money used (the fill) against today's place in the period (the tick).
class _UsedTrack extends StatelessWidget {
  final double used;
  final double elapsed;

  const _UsedTrack({required this.used, required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        height: 14,
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                height: 6,
                width: c.maxWidth * used.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              PositionedDirectional(
                start: (c.maxWidth * elapsed.clamp(0.0, 1.0) - 1).clamp(
                  0.0,
                  math.max(0.0, c.maxWidth - 2),
                ),
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: scheme.onSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The forecast in one sentence, the amount in bold.
class _ForecastNote extends StatelessWidget {
  final SafeToSpendEntity e;

  const _ForecastNote({required this.e});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = e.forecast;
    final base = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      height: 1.45,
      color: scheme.onSurfaceVariant,
    );
    String whole(double v) => CurrencyFormatter.format(
      v.roundToDouble(),
      code: e.currency,
      decimalDigits: 0,
    );
    final IconData icon;
    final Color iconColor;
    final List<InlineSpan> spans;
    final end = f?.projectedEndBalance;
    if (f == null || !f.isReliable || end == null) {
      icon = Icons.info_outline_rounded;
      iconColor = context.tone(AppTone.info).accent;
      spans = [
        TextSpan(
          text: f == null
              ? 'The forecast starts once the budget is running.'
              : SafeToSpendCopy.forecastInsufficient(f),
        ),
      ];
    } else if (end < 0) {
      icon = Icons.trending_down_rounded;
      iconColor = context.tone(AppTone.caution).accent;
      final runsOut = f.exhaustionDate;
      spans = [
        const TextSpan(text: 'At this pace it ends about '),
        TextSpan(
          text: '${whole(-end)} short',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(
          text: runsOut == null
              ? '.'
              : '. ${SafeToSpendCopy.exhaustion(runsOut)}.',
        ),
      ];
    } else {
      icon = Icons.trending_up_rounded;
      iconColor = context.tone(AppTone.positive).accent;
      spans = [
        const TextSpan(text: 'At this pace it ends with about '),
        TextSpan(
          text: '${whole(end)} left',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const TextSpan(text: '.'),
      ];
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.smd),
        Expanded(
          child: Text.rich(TextSpan(children: spans), style: base),
        ),
      ],
    );
  }
}

/// "Where the ₹60,000 is": the whole budget by area. Spent on the left
/// (hatched); bills, kept aside, savings and free stacked on the right, the
/// free money drawn as one square per day left with today's filled.
class _MapCard extends StatelessWidget {
  final SafeToSpendEntity e;
  final VoidCallback onShowWorking;
  final VoidCallback onOpenSpent;

  const _MapCard({
    required this.e,
    required this.onShowWorking,
    required this.onOpenSpent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final money = MoneyMath.forCurrency(e.currency);
    int units(double? v) => v == null || v <= 0 ? 0 : money.toUnits(v);
    final spent = units(e.periodSpent);
    final bills = e.commitmentsAvailable ? units(e.upcomingCommitments) : 0;
    final kept = units(e.reservedAmount);
    final savings = units(e.remainingSavingsTarget);
    final free = units(e.freeToSpend);
    final right = bills + kept + savings + free;
    String fmt(int u) =>
        AppMoney.format(money.toAmount(u), currency: e.currency);
    int share(int part, int whole) =>
        whole <= 0 ? 0 : (part / whole * 1000).round().clamp(1, 1000);

    Widget block(
      String key,
      String label,
      int amount,
      Color color, {
      Widget? top,
      bool hatched = false,
    }) => Container(
      key: Key('money_map_$key'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hatched ? null : color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CustomPaint(
        painter: hatched ? _Hatch(scheme.onSurface) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ?top,
              Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    TextSpan(
                      text: '\n${fmt(amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.clip,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final days = math.max(1, e.remainingDays);
    final overToday = e.overToday > 0;
    // As many columns as make the squares largest while every day fits.
    final squares = LayoutBuilder(
      builder: (context, c) {
        const gap = 3.0;
        var size = 0.0;
        for (var cols = 1; cols <= days; cols++) {
          final rows = (days / cols).ceil();
          final fit = math.min(
            (c.maxWidth - gap * (cols - 1)) / cols,
            (c.maxHeight - gap * (rows - 1)) / rows,
          );
          if (fit > size) size = fit;
        }
        size = math.max(1, size - 0.01);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < days; i++)
              Container(
                key: Key('money_map_day_$i'),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(math.min(4, size / 4)),
                  color: i == 0
                      ? (overToday
                            ? context.tone(AppTone.caution).accent
                            : scheme.primary)
                      : scheme.onPrimaryContainer.withValues(alpha: 0.2),
                ),
              ),
          ],
        );
      },
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Where the ${AppMoney.format(e.budgetAmount, currency: e.currency)} is',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.smd),
          // A picture of the pots below, which carry the figures.
          ExcludeSemantics(
            child: SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (spent > 0)
                    Expanded(
                      flex: share(spent, spent + right),
                      child: GestureDetector(
                        onTap: onOpenSpent,
                        child: block(
                          'spent',
                          'Spent',
                          spent,
                          scheme.surfaceContainer,
                          hatched: true,
                        ),
                      ),
                    ),
                  if (spent > 0 && right > 0) const SizedBox(width: 4),
                  if (right > 0)
                    Expanded(
                      flex: share(right, spent + right),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (k, label, amount, color) in [
                            (
                              'bills',
                              'Bills',
                              bills,
                              context.tone(AppTone.info).container,
                            ),
                            (
                              'kept',
                              'Kept aside',
                              kept,
                              scheme.surfaceContainer,
                            ),
                            (
                              'savings',
                              'Savings',
                              savings,
                              context.tone(AppTone.positive).container,
                            ),
                          ])
                            if (amount > 0) ...[
                              Expanded(
                                flex: share(amount, right),
                                child: block(k, label, amount, color),
                              ),
                              const SizedBox(height: 4),
                            ],
                          if (free > 0)
                            Expanded(
                              flex: share(free, right),
                              child: GestureDetector(
                                onTap: onShowWorking,
                                child: Container(
                                  key: const Key('money_map_free'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: squares),
                                      const SizedBox(height: 6),
                                      Text.rich(
                                        TextSpan(
                                          text: 'Free',
                                          children: [
                                            TextSpan(
                                              text:
                                                  ' ${fmt(free)} · $days ${days == 1 ? 'day' : 'days'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onPrimaryContainer
                                                    .withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: scheme.onPrimaryContainer,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            e.shortfall > 0
                ? 'Bills and money set aside are '
                      '${SafeToSpendCopy.amount(e.shortfall, e.currency)} more '
                      "than what's left."
                : "Each square is one day of free money. Today's is filled.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: e.shortfall > 0 ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diagonal stripes, the design's mark for money already spent.
class _Hatch extends CustomPainter {
  final Color ink;

  const _Hatch(this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ink.withValues(alpha: 0.05),
    );
    final stripe = Paint()
      ..color = ink.withValues(alpha: 0.11)
      ..strokeWidth = 6;
    for (var x = -size.height; x < size.width + size.height; x += 12) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(_Hatch old) => old.ink != ink;
}

/// The map's legend: the same parts, the same order, each opening its pot.
class _Pots extends StatelessWidget {
  final SafeToSpendEntity e;
  final int expenseCount;
  final VoidCallback onShowWorking;
  final VoidCallback onChangeTarget;
  final VoidCallback onOpenBills;
  final VoidCallback onOpenSpent;

  const _Pots({
    required this.e,
    required this.expenseCount,
    required this.onShowWorking,
    required this.onChangeTarget,
    required this.onOpenBills,
    required this.onOpenSpent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = context.tone(AppTone.info);
    final ok = context.tone(AppTone.positive);
    final days = e.remainingDays == 1 ? '1 day' : '${e.remainingDays} days';
    final count = e.commitments.length;
    final next = e.commitments.isEmpty ? null : e.commitments.first;

    Widget amount(double? value, {bool floored = false}) => value == null
        ? const SizedBox.shrink()
        : AppMoney(
            amount: value,
            currency: e.currency,
            floored: floored,
            textAlign: TextAlign.end,
          );

    // Blueprint pots: the amount, then a chevron (each pot opens).
    Widget open(Widget? value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null) Flexible(child: value),
        const SizedBox(width: AppSpacing.xs),
        Icon(
          Icons.chevron_right_rounded,
          color: context.appColors.textTertiary,
        ),
      ],
    );

    Widget tile(IconData icon, Color fill, Color ink, {bool hatched = false}) =>
        Container(
          width: AppSizes.avatarSm,
          height: AppSizes.avatarSm,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: hatched ? null : fill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CustomPaint(
            painter: hatched ? _Hatch(scheme.onSurface) : null,
            child: Icon(icon, size: 20, color: ink),
          ),
        );

    return AppGroupedList(
      dividerIndent: AppSizes.avatarSm + AppSpacing.md,
      children: [
        AppListRow(
          leading: tile(
            Icons.account_balance_wallet_outlined,
            scheme.primaryContainer,
            scheme.onPrimaryContainer,
          ),
          title: 'Free to spend',
          subtitle:
              'Over $days · today’s target '
              '${SafeToSpendCopy.safeAmount(e.dailySafeToSpend, e.currency)}',
          trailing: open(
            e.shortfall > 0
                ? Text(
                    SafeToSpendCopy.freeToSpendValue(e),
                    style: TextStyle(color: scheme.error),
                  )
                : amount(e.freeToSpend, floored: true),
          ),
          onTap: onShowWorking,
        ),
        AppListRow(
          leading: tile(
            Icons.receipt_long_outlined,
            info.container,
            info.accent,
          ),
          title: 'Bills set aside',
          subtitle: !e.commitmentsAvailable
              ? "Couldn't load your bills"
              : count == 0
              ? 'None due before the end'
              : '$count ${count == 1 ? 'bill' : 'bills'} · next ${next!.title}, '
                    '${AppDates.weekday(next.dueDate)}',
          trailing: open(
            e.upcomingCommitments > 0 ? amount(e.upcomingCommitments) : null,
          ),
          onTap: onOpenBills,
        ),
        AppListRow(
          leading: tile(Icons.savings_outlined, ok.container, ok.accent),
          title: 'Savings goal',
          subtitle: e.remainingSavingsTarget == null
              ? 'Not set'
              : 'Left unspent at the end',
          trailing: open(amount(e.remainingSavingsTarget)),
          onTap: onChangeTarget,
        ),
        AppListRow(
          leading: tile(
            Icons.lock_outline_rounded,
            scheme.surfaceContainer,
            scheme.onSurfaceVariant,
          ),
          title: 'Kept aside',
          subtitle: e.reservedAmount == null || e.reservedAmount == 0
              ? 'Not set'
              : 'Not counted as spendable',
          trailing: open(
            e.reservedAmount == null || e.reservedAmount == 0
                ? null
                : amount(e.reservedAmount),
          ),
          onTap: onChangeTarget,
        ),
        AppListRow(
          leading: tile(
            Icons.pie_chart_outline_rounded,
            scheme.surfaceContainer,
            scheme.onSurfaceVariant,
            hatched: true,
          ),
          title: 'Spent',
          subtitle:
              '$expenseCount ${expenseCount == 1 ? 'expense' : 'expenses'}',
          trailing: open(amount(e.periodSpent)),
          onTap: onOpenSpent,
        ),
      ],
    );
  }
}

/// Another budget: a small ring of its day, its amount a day, what is left.
class _OtherRow extends StatelessWidget {
  final OtherBudget other;
  final VoidCallback onTap;

  const _OtherRow({required this.other, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (budget, f) = other;
    final String subtitle;
    if (f == null) {
      subtitle = AppDates.range(budget.startDate, budget.endDate);
    } else if (!f.isRunning) {
      subtitle = f.daysUntilStart > 0
          ? 'Starts ${AppDates.day(budget.startDate)}'
          : 'Ended ${AppDates.day(budget.endDate)}';
    } else {
      subtitle =
          '${SafeToSpendCopy.safeAmount(f.dailySafeToSpend, f.currency)} a day'
          '${f.overToday > 0 ? ' · over today' : ''}';
    }
    return AppListRow(
      leading: SizedBox.square(
        dimension: AppSizes.avatarSm,
        child: Center(
          child: MiniTargetRing(
            spent: f?.isRunning == true ? f!.todayDiscretionary : 0,
            target: f?.isRunning == true ? f!.dailySafeToSpend : 1,
            size: 36,
          ),
        ),
      ),
      title: budget.name,
      subtitle: subtitle,
      trailing: f == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppMoney(
                  amount: f.availableBalance,
                  currency: f.currency,
                  textAlign: TextAlign.end,
                ),
                if (f.isRunning)
                  Text(
                    'left',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
      onTap: onTap,
    );
  }
}
