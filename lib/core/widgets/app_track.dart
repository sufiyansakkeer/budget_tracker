import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';

/// A thin tick drawn across an [AppTrack], e.g. "today" on a budget period
/// or the day free money runs out.
@immutable
class TrackMarker {
  /// 0–1 along the track.
  final double position;
  final Color color;

  const TrackMarker({required this.position, required this.color});
}

/// A rounded progress track with an animated fill and optional [markers].
///
/// It never picks a colour from a ratio (an 80%-used threshold): the caller
/// passes the colour of the status the bar shows, so a bar can never
/// disagree with the chip beside it. The fill animates from its previous
/// value (instant under reduced motion).
class AppTrack extends StatelessWidget {
  /// 0–1; values outside are clamped.
  final double value;
  final Color color;
  final Color? trackColor;
  final double height;
  final List<TrackMarker> markers;

  /// Spoken as "label, value", e.g. "Spent today, 66%".
  final String? semanticLabel;
  final String? semanticValue;

  const AppTrack({
    super.key,
    required this.value,
    required this.color,
    this.trackColor,
    this.height = AppSizes.progressSm,
    this.markers = const [],
    this.semanticLabel,
    this.semanticValue,
  });

  /// How far a marker extends above and below the track.
  static const double _markerOverhang = 4;
  static const double _markerWidth = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final overhang = markers.isEmpty ? 0.0 : _markerOverhang;
    final track = trackColor ?? theme.colorScheme.surfaceContainerHighest;
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.emphasized,
    );

    return Semantics(
      label: semanticLabel,
      value: semanticValue ?? '${(clamped * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height + overhang * 2,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: overhang,
                    height: height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: track,
                        borderRadius: AppSpacing.borderRadiusFull,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: overhang,
                    height: height,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: clamped),
                      duration: duration,
                      curve: AppMotion.value,
                      builder: (context, t, _) => TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: color),
                        duration: duration,
                        curve: AppMotion.value,
                        builder: (context, c, _) => Container(
                          width: width * t,
                          decoration: BoxDecoration(
                            color: c ?? color,
                            borderRadius: AppSpacing.borderRadiusFull,
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final m in markers)
                    Positioned(
                      left:
                          (width * m.position.clamp(0.0, 1.0) -
                                  _markerWidth / 2)
                              .clamp(0.0, width - _markerWidth),
                      top: 0,
                      width: _markerWidth,
                      height: height + overhang * 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: m.color,
                          borderRadius: AppSpacing.borderRadiusFull,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
