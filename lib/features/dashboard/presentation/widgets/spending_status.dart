import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import '../../domain/entities/spending_target_status.dart';
import 'safe_to_spend_copy.dart';

/// Visual mapping for [SpendingTargetStatus]: color, icon and label.
///
/// Status is always communicated with icon + text, never color alone.
class SpendingStatusVisuals {
  final Color color;
  final IconData icon;
  final String label;

  const SpendingStatusVisuals._(this.color, this.icon, this.label);

  factory SpendingStatusVisuals.of(
    BuildContext context,
    SpendingTargetStatus status,
  ) {
    final colors = context.appColors;
    return switch (status) {
      SpendingTargetStatus.onTrack => SpendingStatusVisuals._(
        colors.success,
        Icons.check_circle_rounded,
        'On track',
      ),
      SpendingTargetStatus.nearLimit => SpendingStatusVisuals._(
        colors.warning,
        Icons.warning_amber_rounded,
        'Near limit',
      ),
      SpendingTargetStatus.exceeded => SpendingStatusVisuals._(
        colors.error,
        Icons.error_rounded,
        'Over limit',
      ),
    };
  }
}

/// A status chip that cross-fades when the status changes.
class SpendingStatusChip extends StatelessWidget {
  final SpendingTargetStatus status;
  final bool filled;

  const SpendingStatusChip({
    super.key,
    required this.status,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SpendingStatusVisuals.of(context, status);
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
      child: StatusChip(
        key: ValueKey(status),
        label: visuals.label,
        color: visuals.color,
        icon: visuals.icon,
        filled: filled,
      ),
    );
  }
}

/// Visual mapping for the safe-to-spend [SafeToSpendStatus]: one of the
/// existing semantic tokens (already AA-checked) plus a distinct icon and a
/// label, so no two statuses look alike even without colour.
class SafeToSpendStatusVisuals {
  final Color color;
  final IconData icon;
  final String label;

  const SafeToSpendStatusVisuals._(this.color, this.icon, this.label);

  factory SafeToSpendStatusVisuals.of(
    BuildContext context,
    SafeToSpendStatus status,
  ) {
    final colors = context.appColors;
    final (color, icon) = switch (status) {
      SafeToSpendStatus.onTrack => (colors.success, Icons.check_circle_rounded),
      SafeToSpendStatus.spendingCarefully => (
        colors.warning,
        Icons.warning_amber_rounded,
      ),
      SafeToSpendStatus.budgetAtRisk => (
        colors.warning,
        Icons.trending_down_rounded,
      ),
      SafeToSpendStatus.overDailyAllowance => (
        colors.error,
        Icons.error_rounded,
      ),
      SafeToSpendStatus.overcommitted => (
        colors.error,
        Icons.money_off_rounded,
      ),
      SafeToSpendStatus.overBudget => (
        colors.error,
        Icons.remove_circle_rounded,
      ),
      SafeToSpendStatus.notStarted => (colors.info, Icons.schedule_rounded),
      SafeToSpendStatus.periodEnded => (colors.info, Icons.event_busy_rounded),
    };
    return SafeToSpendStatusVisuals._(
      color,
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
      child: StatusChip(
        key: ValueKey(status),
        label: visuals.label,
        color: visuals.color,
        icon: visuals.icon,
        wrapLabel: wrapLabel,
      ),
    );
  }
}
