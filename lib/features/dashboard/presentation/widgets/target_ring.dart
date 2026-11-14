import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/theme/app_tone.dart';

/// How far round the ring today's spending goes. One lap is today's target;
/// spending past it closes the lap and starts an inner lap for the excess,
/// stopping at one turn. With no target today, any spending is all over.
class TargetRingLaps {
  final double _spent;
  final double _target;

  const TargetRingLaps({required double spent, required double target})
    : _spent = spent,
      _target = target;

  /// The outer lap, 0–1: spent ÷ target.
  double get spent {
    if (_target <= 0) return _spent > 0 ? 1 : 0;
    return (_spent / _target).clamp(0.0, 1.0);
  }

  /// The inner lap, 0–1: the excess over the target ÷ target.
  double get over {
    if (_target <= 0) return _spent > 0 ? 1 : 0;
    return ((_spent - _target) / _target).clamp(0.0, 1.0);
  }

  /// One (start, sweep) per amount in [segments], as fractions of the lap,
  /// laid end to end and cut off at the full lap.
  List<(double, double)> arcs(List<double> segments) {
    if (_target <= 0) return const [];
    final arcs = <(double, double)>[];
    var at = 0.0;
    for (final amount in segments) {
      if (amount <= 0) continue;
      final start = at / _target;
      if (start >= 1) break;
      final sweep = math.min(amount / _target, 1 - start);
      arcs.add((start, sweep));
      at += amount;
    }
    return arcs;
  }
}

/// Today's target as a ring (the blueprint's): the track is the whole
/// target, each of today's expenses is an ink arc in order with a small gap
/// between, and anything over draws a thinner amber lap inside (over today
/// is recoverable, so never the critical red). [child] sits in the middle.
///
/// The ring is one image to assistive technology, read as [semanticsLabel];
/// [child] is excluded so the figures are not read twice. [onTap] opens what
/// the ring stands for (the working).
class TargetRing extends StatelessWidget {
  final double spent;
  final double target;

  /// Today's expenses in the order spent; one arc for [spent] when null or
  /// when they don't add up to it.
  final List<double>? segments;
  final String semanticsLabel;
  final Widget child;
  final VoidCallback? onTap;

  /// An amount not yet saved (quick add): a faint arc after [spent], and a
  /// faint amber inner lap for any part of it past the target.
  final double draft;
  final double diameter;
  final double stroke;

  const TargetRing({
    super.key,
    required this.spent,
    required this.target,
    this.segments,
    required this.semanticsLabel,
    required this.child,
    this.onTap,
    this.draft = 0,
    this.diameter = size,
    this.stroke = 18,
  });

  /// Today's ring on Home.
  static const double size = 232;

  @override
  Widget build(BuildContext context) {
    final laps = TargetRingLaps(spent: spent, target: target);
    final parts = segments;
    final sum = parts?.fold<double>(0, (a, b) => a + b);
    final arcs = laps.arcs(
      parts != null && sum != null && (sum - spent).abs() < 0.005
          ? parts
          : [spent],
    );
    final withDraft = TargetRingLaps(spent: spent + draft, target: target);
    final draftArcs = draft > 0
        ? [
            for (final (s, w) in withDraft.arcs([spent, draft]).skip(1)) (s, w),
          ]
        : const <(double, double)>[];
    final draftOver = draft > 0 ? withDraft.over - laps.over : 0.0;
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.emphasized,
    );
    // Room for the centre inside the inner lap.
    final inset = stroke * 2 + diameter / 23;
    return Semantics(
      image: true,
      button: onTap != null,
      label: semanticsLabel,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // The labelled node above carries the tap for assistive technology.
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: diameter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: duration,
            curve: AppMotion.emphasizedDecelerate,
            builder: (context, t, _) => CustomPaint(
              painter: _RingPainter.of(
                context,
                stroke: stroke,
                gap: diameter > 100 ? 3 : 1.5,
                arcs: [for (final (s, w) in arcs) (s * t, w * t)],
                over: laps.over * t,
                draftArcs: draftArcs,
                draftOver: draftOver,
                overStart: laps.over,
              ),
              child: Padding(
                padding: EdgeInsets.all(inset),
                child: ExcludeSemantics(
                  child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small, still [TargetRing] for lists and chips: how much of a day's
/// target is spent, with no centre. Decorative: the row it sits in says
/// the figures.
class MiniTargetRing extends StatelessWidget {
  final double spent;
  final double target;
  final double size;

  const MiniTargetRing({
    super.key,
    required this.spent,
    required this.target,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final laps = TargetRingLaps(spent: spent, target: target);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter.of(
            context,
            // The blueprint's mini ring: 5 wide, 9 from 60 up.
            stroke: size > 60 ? 9 : math.min(5, size / 5),
            gap: 1.5,
            arcs: laps.arcs([spent]),
            over: laps.over,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double stroke;
  final double gap;
  final List<(double, double)> arcs;
  final double over;
  final List<(double, double)> draftArcs;
  final double draftOver;
  final double overStart;
  final Color track;
  final Color ink;
  final Color overColor;

  const _RingPainter({
    required this.stroke,
    required this.gap,
    required this.arcs,
    required this.over,
    this.draftArcs = const [],
    this.draftOver = 0,
    this.overStart = 0,
    required this.track,
    required this.ink,
    required this.overColor,
  });

  factory _RingPainter.of(
    BuildContext context, {
    required double stroke,
    required double gap,
    required List<(double, double)> arcs,
    required double over,
    List<(double, double)> draftArcs = const [],
    double draftOver = 0,
    double overStart = 0,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return _RingPainter(
      stroke: stroke,
      gap: gap,
      arcs: arcs,
      over: over,
      draftArcs: draftArcs,
      draftOver: draftOver,
      overStart: overStart,
      track: colorScheme.surfaceContainerHighest,
      ink: colorScheme.onSurface.withValues(alpha: 0.72),
      overColor: context.tone(AppTone.caution).accent,
    );
  }

  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    Paint pen(Color color, double width, StrokeCap cap) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = cap;

    canvas.drawCircle(center, radius, pen(track, stroke, StrokeCap.butt));
    final circumference = 2 * math.pi * radius;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (final (start, sweep) in arcs) {
      if (sweep <= 0) continue;
      // The gap is a length on the ring, as in the design's dash array.
      final length = math.max(sweep * circumference - gap, 1.0);
      canvas.drawArc(
        rect,
        _start + 2 * math.pi * start,
        length / radius,
        false,
        pen(ink, stroke, StrokeCap.butt),
      );
    }
    // The draft, faint: what saving it would add.
    for (final (start, sweep) in draftArcs) {
      if (sweep <= 0) continue;
      final length = math.max(sweep * circumference - gap, 1.0);
      canvas.drawArc(
        rect,
        _start + 2 * math.pi * start,
        length / radius,
        false,
        pen(ink.withValues(alpha: 0.28), stroke, StrokeCap.butt),
      );
    }
    final inner = Rect.fromCircle(
      center: center,
      radius: radius - stroke * 0.95,
    );
    if (over > 0) {
      canvas.drawArc(
        inner,
        _start,
        2 * math.pi * over,
        false,
        pen(overColor, stroke * 0.55, StrokeCap.round),
      );
    }
    if (draftOver > 0) {
      canvas.drawArc(
        inner,
        _start + 2 * math.pi * overStart,
        2 * math.pi * draftOver,
        false,
        pen(overColor.withValues(alpha: 0.45), stroke * 0.55, StrokeCap.butt),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.stroke != stroke ||
      old.gap != gap ||
      old.over != over ||
      old.track != track ||
      old.ink != ink ||
      old.overColor != overColor ||
      old.draftOver != draftOver ||
      old.overStart != overStart ||
      !_sameArcs(old.arcs, arcs) ||
      !_sameArcs(old.draftArcs, draftArcs);

  static bool _sameArcs(List<(double, double)> a, List<(double, double)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
