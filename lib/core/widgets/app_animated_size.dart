import 'package:flutter/widgets.dart';

import '../constants/app_motion.dart';

/// [AnimatedSize] that steps aside under reduced motion.
///
/// Callers used to pass `AppMotion.respectReducedMotion(...)` as the
/// duration, which is [Duration.zero] under reduced motion. A zero-length
/// [AnimatedSize] finishes its animation synchronously inside its own
/// layout, which Flutter rejects ("A RenderAnimatedSize was mutated in its
/// own performLayout") the moment the child's size changes. Under reduced
/// motion this widget returns [child] directly, so the size simply updates;
/// otherwise it animates for [duration].
class AppAnimatedSize extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  const AppAnimatedSize({
    super.key,
    required this.child,
    required this.duration,
    this.curve = Curves.linear,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReduced(context) || duration == Duration.zero) {
      return child;
    }
    return AnimatedSize(
      duration: duration,
      curve: curve,
      alignment: alignment,
      child: child,
    );
  }
}
