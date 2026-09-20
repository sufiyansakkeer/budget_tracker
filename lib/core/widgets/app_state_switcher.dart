import 'package:flutter/material.dart';

import '../constants/app_motion.dart';

/// Cross-fades between loading / loaded / empty / error views.
///
/// Give each branch a distinct [Key] (e.g. `ValueKey('loading')`) so the
/// switcher knows when the state actually changed.
class AppStateSwitcher extends StatelessWidget {
  final Widget child;
  final Duration? duration;

  const AppStateSwitcher({super.key, required this.child, this.duration});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.respectReducedMotion(
        context,
        duration ?? AppMotion.medium,
      ),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: child,
    );
  }
}
