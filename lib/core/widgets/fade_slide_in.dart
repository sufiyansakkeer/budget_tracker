import 'package:flutter/material.dart';

import '../constants/app_motion.dart';

/// Fades and gently slides its child upward into place once, when first
/// mounted. Use [index] to stagger consecutive items.
///
/// Give list rows a stable [key] (e.g. `ValueKey(item.id)`) so re-sorting or
/// refreshing reuses the element and does not replay the entrance. Pass
/// [animate] false to render the child directly (e.g. for rows the user has
/// already seen when they scroll back into view); the decision is captured
/// when the widget mounts so a mid-animation rebuild never cuts it short.
///
/// Reduced-motion settings disable the effect.
class FadeSlideIn extends StatefulWidget {
  final Widget child;

  /// Position in a list — each step adds [AppMotion.staggerStep] of delay.
  /// Clamped so long lists never wait on a slow cascade.
  final int index;

  /// Vertical offset the child travels, in logical pixels.
  final double offset;

  /// When false the child is returned as-is.
  final bool animate;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
    this.animate = true,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  late final bool _animate = widget.animate;

  @override
  Widget build(BuildContext context) {
    if (!_animate || AppMotion.isReduced(context)) return widget.child;

    final delay = AppMotion.staggerStep * widget.index.clamp(0, 8);
    final total = AppMotion.medium + delay;
    final startFraction = delay.inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(startFraction, 1, curve: AppMotion.enter),
      child: widget.child,
      builder: (context, t, child) {
        if (t >= 1) return child!;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
