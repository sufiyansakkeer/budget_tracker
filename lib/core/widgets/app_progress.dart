import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import '../theme/contrast.dart';
import '../theme/app_colors_extension.dart';

/// A reusable linear progress bar with semantic color derived from
/// utilization. Both the fill and its color animate from the previous state
/// to the new one, so crossing into "near limit" or "over budget" reads as a
/// smooth change rather than a snap.
class AppProgress extends StatelessWidget {
  /// 0.0 – 1.0 (or beyond 1.0 to indicate over-budget).
  final double value;
  final double height;
  final bool showLabel;

  /// Overrides the automatic status color.
  final Color? color;

  /// Accessibility label, e.g. "Budget used".
  final String? semanticLabel;

  const AppProgress({
    super.key,
    required this.value,
    this.height = AppSizes.progressMd,
    this.showLabel = false,
    this.color,
    this.semanticLabel,
  });

  /// Returns the semantic color for a utilization value using the active
  /// palette.
  ///
  /// * < 80% → success
  /// * 80–100% → warning
  /// * > 100% → error
  static Color colorFor(BuildContext context, double utilization) {
    final appColors = context.appColors;
    if (utilization >= 1.0) return appColors.error;
    if (utilization >= 0.8) return appColors.warning;
    return appColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final barColor = color ?? colorFor(context, value);
    final percentage = (value * 100).clamp(0.0, 100.0);
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.emphasized,
    );

    return Semantics(
      label: semanticLabel,
      value: '${percentage.toStringAsFixed(0)}%',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: barColor),
          duration: duration,
          curve: AppMotion.value,
          builder: (context, animatedColor, _) {
            final fill = animatedColor ?? barColor;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLabel) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        // The bar already carries the colour meaning; the
                        // number needs a guaranteed-legible colour.
                        color: Contrast.ensureContrast(
                          fill,
                          theme.colorScheme.surface,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: clamped),
                  duration: duration,
                  curve: AppMotion.value,
                  builder: (context, animated, _) {
                    return ClipRRect(
                      borderRadius: AppSpacing.borderRadiusFull,
                      child: LinearProgressIndicator(
                        value: animated,
                        minHeight: height,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: fill,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A circular progress ring that animates to its value and color, with an
/// optional centre child (icon or label).
class AppProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Widget? center;
  final String? semanticLabel;

  const AppProgressRing({
    super.key,
    required this.value,
    this.size = AppSizes.ringMd,
    this.strokeWidth = 8,
    this.color,
    this.center,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final ringColor = color ?? AppProgress.colorFor(context, value);
    final percentage = (value * 100).clamp(0.0, 100.0);
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.emphasized,
    );

    return Semantics(
      label: semanticLabel,
      value: '${percentage.toStringAsFixed(0)}%',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: ringColor),
          duration: duration,
          curve: AppMotion.value,
          child: center,
          builder: (context, animatedColor, child) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: clamped),
              duration: duration,
              curve: AppMotion.value,
              child: child,
              builder: (context, animated, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: animated,
                        strokeWidth: strokeWidth,
                        strokeCap: StrokeCap.round,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: animatedColor ?? ringColor,
                      ),
                    ),
                    if (child != null) child,
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
