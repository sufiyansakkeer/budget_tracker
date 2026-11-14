import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'safe_to_spend_copy.dart';

/// Tomorrow's target as two outcomes side by side (blueprint): stop now
/// (highlighted), or spend the rest of today's target (then tomorrow's
/// equals today's, exactly). Over today, the second is what each later day
/// loses instead. Nothing on the last day of the period.
class TomorrowCard extends StatelessWidget {
  final SafeToSpendEntity safeToSpend;

  const TomorrowCard({super.key, required this.safeToSpend});

  @override
  Widget build(BuildContext context) {
    final e = safeToSpend;
    final tomorrow = e.tomorrowIfNoMoreSpending;
    if (tomorrow == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final perDay = e.overTodayPerRemainingDay;
    final first = (
      'If you spend nothing more today',
      SafeToSpendCopy.safeAmount(tomorrow, e.currency),
    );
    final second = e.overToday > 0
        ? (
            'Each later day',
            perDay == null || perDay <= 0
                ? '—'
                : '−${SafeToSpendCopy.amount(perDay, e.currency)}',
          )
        : (
            'If you spend the rest',
            SafeToSpendCopy.safeAmount(e.dailySafeToSpend, e.currency),
          );

    Widget cell((String, String) c, {required bool lead}) {
      final ink = lead ? scheme.onPrimaryContainer : scheme.onSurface;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: lead ? scheme.primaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.smd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.$1,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: lead ? ink : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // One line: a figure never breaks across lines.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  c.$2,
                  maxLines: 1,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: CurrencyFormatter.forSpeech(
        "Tomorrow's target. ${first.$1}, ${first.$2}. "
        '${second.$1}, ${second.$2}.',
      ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Tomorrow's target",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cell(first, lead: true)),
                const SizedBox(width: AppSpacing.smd),
                Expanded(child: cell(second, lead: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
