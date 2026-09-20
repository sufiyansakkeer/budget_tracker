import 'package:flutter/material.dart';

import '../constants/app_motion.dart';

/// Signature for [ChartReveal.builder].
///
/// [t] runs 0 → 1 once while the chart first appears; [revealing] is true
/// during that sweep so charts can disable their own data-change animation
/// (which would otherwise fight the reveal) and re-enable it afterwards.
typedef ChartRevealBuilder =
    Widget Function(BuildContext context, double t, bool revealing);

/// Plays a single "draw in" sweep the first time a chart is shown.
///
/// Bars grow upward, lines are drawn left to right, rings expand — whatever
/// the [builder] decides to do with [t]. Later dataset changes are left to
/// the chart's own implicit animation, so charts never animate continuously.
/// Reduced-motion settings render the finished chart immediately.
class ChartReveal extends StatefulWidget {
  final ChartRevealBuilder builder;

  const ChartReveal({super.key, required this.builder});

  @override
  State<ChartReveal> createState() => _ChartRevealState();
}

class _ChartRevealState extends State<ChartReveal> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done || AppMotion.isReduced(context)) {
      return widget.builder(context, 1, false);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.emphasized,
      curve: AppMotion.emphasizedDecelerate,
      onEnd: () {
        if (mounted) setState(() => _done = true);
      },
      builder: (context, t, _) => widget.builder(context, t, true),
    );
  }
}
