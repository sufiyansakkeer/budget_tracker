import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_track.dart';
import '../../../budget/presentation/widgets/budget_list_items.dart';

/// The budget's plan against what has been spent so far in its period: a
/// bar of the amount used with a tick where today falls, so being ahead of
/// or behind an even pace reads at a glance. Facts only, no status word, so
/// it can never disagree with Home.
class PlannedVsActual extends StatelessWidget {
  final BudgetEntity budget;

  /// Spent in the report's range: the budget's period up to today.
  final double spent;
  final DateTime now;

  const PlannedVsActual({
    super.key,
    required this.budget,
    required this.spent,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final planned = budget.monthlyAmount;
    final over = spent > planned;
    final critical = context.tone(AppTone.critical).accent;
    // Drawing geometry only.
    final used = planned <= 0 ? 0.0 : (spent / planned).clamp(0.0, 1.0);
    final elapsed = budget.totalDays <= 0
        ? 0.0
        : (budget.daysElapsed(now) / budget.totalDays).clamp(0.0, 1.0);
    final percent = planned <= 0 ? 0 : (spent / planned * 100).round();
    final dayOf = BudgetPeriodCopy.dayOf(budget, now);
    final when = BudgetPeriodCopy.when(budget, now);
    final spentText = AppMoney.format(spent, currency: budget.currency);
    final plannedText = AppMoney.format(planned, currency: budget.currency);

    return AppSection(
      title: 'Planned vs actual',
      subtitle: '${budget.name} · ${BudgetPeriodCopy.range(budget)}',
      child: Semantics(
        label:
            '$spentText spent of $plannedText planned, $percent% used. '
            '${[?dayOf, when].join(', ')}.',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                AppMoney(
                  amount: spent,
                  currency: budget.currency,
                  role: MoneyRole.title,
                  color: over ? critical : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Text('of $plannedText planned', style: muted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTrack(
              value: used,
              height: AppSizes.progressSm,
              color: over ? critical : theme.colorScheme.onSurfaceVariant,
              markers: [
                TrackMarker(
                  position: elapsed,
                  color: theme.colorScheme.onSurface,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(['$percent% used', ?dayOf, when].join(' · '), style: muted),
            Text(
              over
                  ? '${AppMoney.format(spent - planned, currency: budget.currency)} over the plan.'
                  : 'The tick marks today: a bar short of it is under an '
                        'even pace.',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}
