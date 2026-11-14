import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../dashboard/presentation/widgets/safe_to_spend_copy.dart';

/// What an amount not yet saved does to today (blueprint): two lines,
/// "Left today ₹297.62 → over by ₹92.38" and "Tomorrow ₹880.57 → ₹863.61",
/// from [before] (nothing added) to [after] (the amount counted). Until an
/// amount is typed each line shows its one figure.
class TodayImpact extends StatelessWidget {
  final SafeToSpendEntity before;
  final SafeToSpendEntity after;

  const TodayImpact({super.key, required this.before, required this.after});

  static String _left(SafeToSpendEntity e) => e.overToday > 0
      ? 'over by ${SafeToSpendCopy.amount(e.overToday, e.currency)}'
      : SafeToSpendCopy.safeAmount(e.remainingToday, e.currency);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final changed = after.todayDiscretionary != before.todayDiscretionary;
    final caution = context.tone(AppTone.caution).accent;
    final tomorrowBefore = before.tomorrowIfNoMoreSpending;
    final tomorrowAfter = after.tomorrowIfNoMoreSpending;

    Widget line(String label, String from, String to, {bool worse = false}) {
      final figure = theme.textTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w800,
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(from, style: figure),
            if (changed) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(to, style: figure?.copyWith(color: worse ? caution : null)),
            ],
          ],
        ),
      );
    }

    final leftFrom = _left(before);
    final leftTo = _left(after);
    final spoken = [
      changed ? 'Left today, $leftFrom, becomes $leftTo' : 'Left today, $leftFrom',
      if (tomorrowBefore != null && tomorrowAfter != null)
        changed
            ? 'Tomorrow, ${SafeToSpendCopy.safeAmount(tomorrowBefore, before.currency)}, '
                  'becomes ${SafeToSpendCopy.safeAmount(tomorrowAfter, after.currency)}'
            : 'Tomorrow, ${SafeToSpendCopy.safeAmount(tomorrowBefore, before.currency)}',
    ].join('. ');

    return Semantics(
      key: const Key('todayImpact'),
      container: true,
      label: CurrencyFormatter.forSpeech(spoken),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line('Left today', leftFrom, leftTo, worse: after.overToday > 0),
          if (tomorrowBefore != null && tomorrowAfter != null) ...[
            const SizedBox(height: 6),
            line(
              'Tomorrow',
              SafeToSpendCopy.safeAmount(tomorrowBefore, before.currency),
              SafeToSpendCopy.safeAmount(tomorrowAfter, after.currency),
            ),
          ],
        ],
      ),
    );
  }
}
