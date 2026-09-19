import 'package:flutter/material.dart';

import '../constants/app_motion.dart';

/// Fades and gently slides its child upward into place once, when first
/// mounted. Use [index] to stagger consecutive items.
///
/// Reduced-motion settings disable the effect.
class FadeSlideIn extends StatelessWidget {
  final Widget child;

  /// Position in a list — each step adds [AppMotion.staggerStep] of delay.
  final int index;

  /// Vertical offset the child travels, in logical pixels.
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) return child;

    final delay = AppMotion.staggerStep * index.clamp(0, 8);
    final total = AppMotion.medium + delay;
    final startFraction = delay.inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(startFraction, 1, curve: AppMotion.enter),
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
