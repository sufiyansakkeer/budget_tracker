import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'safe_to_spend_copy.dart';

/// Visual mapping for the safe-to-spend [SafeToSpendStatus]: a tone, a
/// distinct icon and a label, so no two statuses look alike even without
/// colour.
///
/// Tones follow one rule: red ([AppTone.critical]) only when money is
/// already gone (over budget, or bills and money set aside exceed what is
/// left). Going over today's amount is recoverable, because tomorrow's
/// figure absorbs it, so it is [AppTone.caution] like "At risk".
class SafeToSpendStatusVisuals {
  final AppTone tone;

  /// The tone's accent, for an icon or a bar on a card.
  final Color color;
  final IconData icon;
  final String label;

  const SafeToSpendStatusVisuals._(
    this.tone,
    this.color,
    this.icon,
    this.label,
  );

  /// The tone for [status], without a [BuildContext].
  static AppTone toneOf(SafeToSpendStatus status) => switch (status) {
    SafeToSpendStatus.onTrack => AppTone.positive,
    SafeToSpendStatus.spendingCarefully => AppTone.caution,
    SafeToSpendStatus.budgetAtRisk => AppTone.caution,
    SafeToSpendStatus.overDailyAllowance => AppTone.caution,
    SafeToSpendStatus.overcommitted => AppTone.critical,
    SafeToSpendStatus.overBudget => AppTone.critical,
    SafeToSpendStatus.notStarted => AppTone.neutral,
    SafeToSpendStatus.periodEnded => AppTone.neutral,
  };

  factory SafeToSpendStatusVisuals.of(
    BuildContext context,
    SafeToSpendStatus status,
  ) {
    final icon = switch (status) {
      SafeToSpendStatus.onTrack => Icons.check_circle_rounded,
      SafeToSpendStatus.spendingCarefully => Icons.warning_amber_rounded,
      SafeToSpendStatus.budgetAtRisk => Icons.trending_down_rounded,
      SafeToSpendStatus.overDailyAllowance => Icons.error_rounded,
      SafeToSpendStatus.overcommitted => Icons.money_off_rounded,
      SafeToSpendStatus.overBudget => Icons.remove_circle_rounded,
      SafeToSpendStatus.notStarted => Icons.schedule_rounded,
      SafeToSpendStatus.periodEnded => Icons.event_busy_rounded,
    };
    final tone = toneOf(status);
    return SafeToSpendStatusVisuals._(
      tone,
      context.tone(tone).accent,
      icon,
      SafeToSpendCopy.statusLabel(status),
    );
  }
}

/// A safe-to-spend status chip that cross-fades when the status changes.
class SafeToSpendStatusChip extends StatelessWidget {
  final SafeToSpendStatus status;

  /// See [StatusChip.wrapLabel].
  final bool wrapLabel;

  const SafeToSpendStatusChip({
    super.key,
    required this.status,
    this.wrapLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SafeToSpendStatusVisuals.of(context, status);
    return AnimatedSwitcher(
      duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: StatusChip.tone(
        key: ValueKey(status),
        label: visuals.label,
        tone: visuals.tone,
        icon: visuals.icon,
        wrapLabel: wrapLabel,
      ),
    );
  }
}
