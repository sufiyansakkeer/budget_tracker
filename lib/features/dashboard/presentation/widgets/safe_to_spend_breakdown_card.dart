import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/contrast.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_forecast.dart';
import 'dashboard_info.dart';
import 'safe_to_spend_copy.dart';
import '../../../../core/widgets/app_animated_size.dart';

/// "Free to spend": how the active budget's remaining money becomes the
/// amount that is free to spend until its end date, followed by the
/// forecast at the average pace so far.
///
/// Remaining in budget − Bills due − Kept aside − Savings goal = Free to
/// spend. Every figure comes from the engine's [SafeToSpendEntity]; "Not
/// set" (no amount chosen), "₹0", "Unavailable" (bills could not be read)
/// and "No bills due this period" are kept distinct.
///
/// Not tappable as a whole; each row is one screen-reader label, and the
/// bills row expands to list exactly the occurrences deducted.
class SafeToSpendBreakdownCard extends StatefulWidget {
  final SafeToSpendEntity safeToSpend;

  /// Shown right after the "= Free to spend" row, before the forecast: the
  /// Home sheet continues the working there down to today's amount.
  final Widget? afterFreeToSpend;

  const SafeToSpendBreakdownCard({
    super.key,
    required this.safeToSpend,
    this.afterFreeToSpend,
  });

  @override
  State<SafeToSpendBreakdownCard> createState() =>
      _SafeToSpendBreakdownCardState();
}

class _SafeToSpendBreakdownCardState extends State<SafeToSpendBreakdownCard> {
  bool _billsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.safeToSpend;
    final cur = e.currency;
    final forecast = e.forecast;

    // Flat: it is shown in a sheet (Home) or on a sunken surface (a budget
    // that has not started), never as a bordered card of its own.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  'Free to spend',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            InfoIcon(content: DashboardInfo.freeToSpend(cur)),
          ],
        ),
        BreakdownRow(
          label: 'Remaining in budget',
          value: SafeToSpendCopy.amount(e.availableBalance, cur),
          semanticsLabel:
              'Remaining in budget, '
              '${SafeToSpendCopy.amount(e.availableBalance, cur)}',
        ),
        ..._billsRows(context, e),
        BreakdownRow(
          operator: '−',
          label: 'Kept aside',
          value: e.reservedAmount == null
              ? 'Not set'
              : SafeToSpendCopy.amount(e.reservedAmount!, cur),
          muted: e.reservedAmount == null,
          semanticsLabel: e.reservedAmount == null
              ? 'Kept aside, not set'
              : 'Kept aside, minus '
                    '${SafeToSpendCopy.amount(e.reservedAmount!, cur)}',
        ),
        BreakdownRow(
          operator: '−',
          label: 'Savings goal',
          value: e.remainingSavingsTarget == null
              ? 'Not set'
              : SafeToSpendCopy.amount(e.remainingSavingsTarget!, cur),
          muted: e.remainingSavingsTarget == null,
          semanticsLabel: e.remainingSavingsTarget == null
              ? 'Savings goal, not set'
              : 'Savings goal, minus '
                    '${SafeToSpendCopy.amount(e.remainingSavingsTarget!, cur)}',
        ),
        Divider(height: AppSpacing.md, color: theme.colorScheme.outlineVariant),
        BreakdownRow(
          operator: '=',
          label: SafeToSpendCopy.freeToSpendLabel(e),
          value: SafeToSpendCopy.freeToSpendValue(e),
          emphasized: true,
          // A shortfall is money the bills need and the budget does not
          // have: already gone, so critical.
          valueColor: e.shortfall > 0
              ? context.tone(AppTone.critical).accent
              : null,
          semanticsLabel:
              'Free to spend until ${SafeToSpendCopy.spokenDate(e.endDate)}, '
              '${SafeToSpendCopy.freeToSpendValue(e)}',
        ),
        ?widget.afterFreeToSpend,
        if (forecast != null) ...[
          Divider(
            height: AppSpacing.lg,
            color: theme.colorScheme.outlineVariant,
          ),
          _ForecastSection(entity: e, forecast: forecast),
        ],
      ],
    );
  }

  List<Widget> _billsRows(BuildContext context, SafeToSpendEntity e) {
    final cur = e.currency;
    if (!e.commitmentsAvailable) {
      return const [
        BreakdownRow(
          operator: '−',
          label: 'Bills due',
          value: 'Unavailable',
          muted: true,
          semanticsLabel: "Bills due, unavailable. Bills couldn't be loaded",
        ),
      ];
    }
    if (e.commitments.isEmpty) {
      final zero = SafeToSpendCopy.amount(0, cur);
      return [
        BreakdownRow(
          operator: '−',
          label: 'No bills due this period',
          value: zero,
          semanticsLabel: 'No bills due this period, $zero',
        ),
      ];
    }

    final theme = Theme.of(context);
    final total = SafeToSpendCopy.amount(e.upcomingCommitments, cur);
    final count = e.commitments.length;
    final duration = AppMotion.respectReducedMotion(context, AppMotion.medium);
    void toggle() => setState(() => _billsExpanded = !_billsExpanded);

    return [
      Semantics(
        button: true,
        expanded: _billsExpanded,
        label:
            'Bills due by ${SafeToSpendCopy.spokenDate(e.endDate)}, '
            '$count ${count == 1 ? 'bill' : 'bills'}, minus $total. '
            '${_billsExpanded ? 'Hide' : 'Show'} bills',
        onTap: toggle,
        excludeSemantics: true,
        child: InkWell(
          onTap: toggle,
          borderRadius: AppSpacing.borderRadiusSm,
          child: BreakdownRow(
            operator: '−',
            label: SafeToSpendCopy.billsDueLabel(e),
            value: total,
            trailing: AnimatedRotation(
              turns: _billsExpanded ? 0.5 : 0,
              duration: duration,
              child: Icon(
                Icons.expand_more_rounded,
                size: AppSizes.iconSm,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
      AppAnimatedSize(
        duration: duration,
        curve: AppMotion.standardCurve,
        alignment: Alignment.topCenter,
        child: _billsExpanded
            ? Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.lg,
                  bottom: AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final o in e.commitments)
                      _OccurrenceLine(
                        key: ValueKey('occurrence_${o.billId}_${o.dueDate}'),
                        text: SafeToSpendCopy.occurrenceLine(o, cur),
                        overdue: o.isOverdue,
                        semanticsLabel: SafeToSpendCopy.occurrenceSemantics(
                          o,
                          cur,
                        ),
                      ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    ];
  }
}

/// One line of the breakdown: operator, label, value. At least 48dp tall so
/// the expandable bills row is a full-size tap target.
///
/// The value hugs the right edge and the label takes the rest of the row.
/// At large text sizes the value moves under its label instead, so neither
/// is cut short.
class BreakdownRow extends StatelessWidget {
  final String? operator;
  final String label;
  final String value;
  final String? semanticsLabel;
  final bool emphasized;
  final bool muted;
  final Color? valueColor;
  final Widget? trailing;

  const BreakdownRow({
    super.key,
    this.operator,
    required this.label,
    required this.value,
    this.semanticsLabel,
    this.emphasized = false,
    this.muted = false,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typography = context.appTypography;
    final labelStyle =
        (emphasized ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: emphasized
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            );
    final valueStyle =
        (emphasized ? typography.moneyTitle : typography.moneyBody).copyWith(
          color:
              valueColor ??
              (muted ? colorScheme.onSurfaceVariant : colorScheme.onSurface),
          fontWeight: muted ? FontWeight.w500 : null,
        );
    final operatorBox = SizedBox(
      width: AppSpacing.lg,
      child: Text(operator ?? '', style: labelStyle),
    );
    final valueText = Text(
      value,
      style: valueStyle,
      maxLines: 1,
      textAlign: TextAlign.end,
    );
    // Roughly 1.5× text: past it a label and a value no longer share a
    // line comfortably on a phone.
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 24;

    final Widget row;
    if (stacked) {
      row = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            operatorBox,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label, style: labelStyle),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: valueText,
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        trailing!,
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      row = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              operatorBox,
              Expanded(
                child: Text(
                  label,
                  style: labelStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.45,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: valueText,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ],
            ],
          ),
        ),
      );
    }
    if (semanticsLabel == null) return row;
    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: row,
    );
  }
}

/// One deducted bill occurrence: "Rent · 28 Oct · ₹12,000", plus "Overdue".
class _OccurrenceLine extends StatelessWidget {
  final String text;
  final bool overdue;
  final String semanticsLabel;

  const _OccurrenceLine({
    super.key,
    required this.text,
    required this.overdue,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (overdue) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Overdue',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.readable(context.appColors.error),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Where the period is heading at the average pace of the completed days.
/// Informational only; it never changes today's amount.
class _ForecastSection extends StatelessWidget {
  final SafeToSpendEntity entity;
  final SafeToSpendForecast forecast;

  const _ForecastSection({required this.entity, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entity;
    final f = forecast;
    final cur = e.currency;
    final title = Semantics(
      header: true,
      child: Text(
        'Forecast',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (!f.isReliable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: AppSpacing.xs),
          Text(
            SafeToSpendCopy.forecastInsufficient(f),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final average = SafeToSpendCopy.amount(f.averageDaily!, cur);
    final projected = SafeToSpendCopy.amount(f.projectedPeriodSpending!, cur);
    final endBalance = f.projectedEndBalance!;
    final endText = SafeToSpendCopy.amount(endBalance.abs(), cur);
    final end = SafeToSpendCopy.date(e.endDate);
    final spokenEnd = SafeToSpendCopy.spokenDate(e.endDate);
    final exhaustion = f.exhaustionDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        BreakdownRow(
          label: 'Average a day so far',
          value: average,
          semanticsLabel: 'Average a day so far, $average',
        ),
        BreakdownRow(
          label: 'Projected spending by $end',
          value: projected,
          semanticsLabel: 'Projected spending by $spokenEnd, $projected',
        ),
        endBalance >= 0
            ? BreakdownRow(
                label: 'Projected left on $end',
                value: endText,
                semanticsLabel: 'Projected left on $spokenEnd, $endText',
              )
            : BreakdownRow(
                label: 'Projected short on $end',
                value: '$endText short',
                // A projection, not money already gone: caution.
                valueColor: context.tone(AppTone.caution).accent,
                semanticsLabel: 'Projected short on $spokenEnd, $endText',
              ),
        if (exhaustion != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.trending_down_rounded,
                size: AppSizes.iconSm,
                color: context.appColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  SafeToSpendCopy.exhaustion(exhaustion),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
