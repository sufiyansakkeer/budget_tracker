import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/spending_target_status.dart';

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
