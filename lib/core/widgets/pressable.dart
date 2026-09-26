import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../constants/app_motion.dart';

/// Adds a subtle press-scale response to any tappable surface.
///
/// Wrap cards, buttons or tiles that already have their own [InkWell]; the
/// scale is applied on top of the ripple so the surface feels physical
/// without extra decoration. Pressing in is quick ([AppMotion.micro]) and
/// the release eases back ([AppMotion.standard]) so a fast tap still reads.
///
/// Disabled controls should pass [enabled] false so they never react.
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
    this.pressedScale = AppMotion.pressedScale,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  Offset? _downPosition;

  void _set(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _onMove(PointerMoveEvent event) {
    final down = _downPosition;
    if (down == null || !_pressed) return;
    // A drag past the touch slop is a scroll or swipe, not a press: let the
    // surface go so it does not stay shrunk under the finger.
    if ((event.position - down).distance > kTouchSlop) _set(false);
  }

  @override
  void didUpdateWidget(covariant Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (event) {
        _downPosition = event.position;
        _set(true);
      },
      onPointerMove: _onMove,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: AppMotion.respectReducedMotion(
          context,
          _pressed ? AppMotion.micro : AppMotion.standard,
        ),
        curve: AppMotion.standardCurve,
        child: widget.child,
      ),
    );
  }
}
