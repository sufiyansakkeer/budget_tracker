import 'package:flutter/material.dart';

import '../constants/app_motion.dart';

/// Shows [child] only if it is still on screen after [delay], then fades it
/// in.
///
/// For loading placeholders: Monivo reads a local database, so most screens
/// load in well under the delay and a skeleton would only flash. Under
/// reduced motion the child appears after the delay without a fade. Built on
/// an animation rather than a timer, so a widget test never ends with a
/// timer pending.
class DelayedReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const DelayedReveal({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 300),
  });

  @override
  State<DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<DelayedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  static const Duration _fade = AppMotion.standard;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + _fade;
    _controller = AnimationController(vsync: this, duration: total)..forward();
    final start = widget.delay.inMicroseconds / total.inMicroseconds;
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: AppMotion.enter),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReduced(context)) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Opacity(opacity: _opacity.value > 0 ? 1 : 0, child: child),
        child: widget.child,
      );
    }
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
