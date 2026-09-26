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
    // A state change while the tab is hidden (tickers paused: a preloaded
    // tab finishing its first load, a refresh from another tab) switches
    // instantly. Otherwise the cross-fade would start when the tab is next
    // shown and play on top of the tab transition.
    final instant = !TickerMode.of(context) || AppMotion.isReduced(context);
    return AnimatedSwitcher(
      duration: instant ? Duration.zero : (duration ?? AppMotion.medium),
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
