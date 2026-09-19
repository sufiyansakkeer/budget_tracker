import 'package:flutter/material.dart';

import '../constants/app_motion.dart';

/// Adds a subtle press-scale response to any tappable surface.
///
/// Wrap cards or tiles that have their own [InkWell]; the scale is applied on
/// top of the ripple so the card feels physical without extra decoration.
class Pressable extends StatefulWidget {
  final Widget child;
  final bool enabled;

  /// Scale applied while pressed. Keep this close to 1 — it's a hint, not a
  /// bounce.
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.98,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
        curve: AppMotion.standardCurve,
        child: widget.child,
      ),
    );
  }
}
