import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';
import 'delayed_reveal.dart';

/// Wraps skeleton placeholders in a single, shared shimmer sweep.
///
/// One [AnimationController] drives every [SkeletonBox] beneath it, so a whole
/// loading layout costs one ticker. Honors reduced-motion settings by
/// rendering static placeholders.
///
/// Placeholders appear only after [delay] (300 ms): Monivo reads a local
/// database, so most loads finish sooner and a skeleton would only flash.
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const Shimmer({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 300),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );

  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start or stop the sweep as the accessibility setting changes; a static
    // placeholder must not keep a ticker alive.
    _reduced = AppMotion.isReduced(context);
    if (_reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sweep = _sweep(context);
    if (widget.delay == Duration.zero) return sweep;
    return DelayedReveal(delay: widget.delay, child: sweep);
  }

  Widget _sweep(BuildContext context) {
    if (_reduced) {
      return widget.child;
    }
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHigh;
    final highlight = theme.brightness == Brightness.dark
        ? Color.lerp(base, theme.colorScheme.surface, -0.25)!
        : Color.lerp(base, theme.colorScheme.surface, 0.6)!;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradientTransform(t * 2 - 1),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double percent;
  const _SlideGradientTransform(this.percent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0, 0);
  }
}

/// A placeholder block used to build skeleton loading states.
///
/// Place inside a [Shimmer] to animate.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppSpacing.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A placeholder one line of [style] tall, so a skeleton's text lines are
/// sized by the type scale they stand in for instead of by hand.
class SkeletonText extends StatelessWidget {
  final TextStyle? style;
  final double? width;

  const SkeletonText({super.key, required this.style, this.width});

  @override
  Widget build(BuildContext context) {
    final size = style?.fontSize ?? 14;
    final lineHeight = size * (style?.height ?? 1.2);
    // The glyph block sits inside the line box; the gap keeps stacked
    // placeholders from merging into one slab.
    return SizedBox(
      height: lineHeight,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SkeletonBox(width: width, height: size * 0.8),
      ),
    );
  }
}

/// A single skeleton row shaped like a list tile (avatar + two lines + amount).
class SkeletonListTile extends StatelessWidget {
  /// Size of the leading tile.
  final double leadingSize;

  const SkeletonListTile({super.key, this.leadingSize = AppSizes.avatarMd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
      child: Row(
        children: [
          SkeletonBox(
            width: leadingSize,
            height: leadingSize,
            radius: AppSpacing.radiusSmd,
          ),
          const SizedBox(width: AppSpacing.smd),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 14),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 90, height: 12),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          const SkeletonBox(width: 64, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton of the Home screen, with the same structure, padding and type
/// sizes as the loaded layout, so the cross-fade to content does not jump:
/// header, the hero surface, the "Free to spend" row and a list section.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final type = context.appTypography;
    final heroColor =
        theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
    // Two lines (title + caption) and the row's vertical padding.
    final freeRowHeight =
        (text.titleSmall?.fontSize ?? 14) * (text.titleSmall?.height ?? 1.4) +
        (text.bodySmall?.fontSize ?? 12) * (text.bodySmall?.height ?? 1.4) +
        AppSpacing.xxs +
        AppSpacing.smd * 2;

    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.pagePaddingWithFab,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SkeletonText(style: type.eyebrow, width: 150),
                  const SizedBox(height: AppSpacing.xs),
                  SkeletonText(style: text.headlineSmall, width: 210),
                  SkeletonText(style: text.bodySmall, width: 130),
                  const SizedBox(height: AppSpacing.md),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: heroColor,
                      borderRadius: AppSpacing.borderRadiusLg,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.mlg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SkeletonText(style: text.titleSmall, width: 150),
                          SkeletonText(style: type.moneyHero, width: 180),
                          const SizedBox(height: AppSpacing.sm),
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: SkeletonBox(
                              width: 88,
                              height: 24,
                              radius: AppSpacing.radiusFull,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.mlg),
                          const SkeletonBox(
                            height: AppSizes.progressSm,
                            radius: AppSpacing.radiusFull,
                          ),
                          const SizedBox(height: AppSpacing.smd),
                          Row(
                            children: [
                              SkeletonText(style: type.moneyBody, width: 70),
                              const Spacer(),
                              SkeletonText(style: type.moneyBody, width: 90),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SkeletonText(style: text.titleSmall, width: 190),
                          const SizedBox(height: AppSpacing.sm),
                          const SkeletonBox(
                            height: AppSizes.progressThin,
                            radius: AppSpacing.radiusFull,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SkeletonBox(
                    height: freeRowHeight,
                    radius: AppSpacing.radiusMd,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SkeletonText(style: text.titleMedium, width: 110),
                  for (var i = 0; i < 3; i++)
                    const SkeletonListTile(leadingSize: AppSizes.avatarSm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton layout for a list of expense tiles.
class ExpenseListSkeleton extends StatelessWidget {
  final int itemCount;

  const ExpenseListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.pagePadding,
        itemCount: itemCount,
        itemBuilder: (context, index) => const SkeletonListTile(),
      ),
    );
  }
}

/// Generic skeleton for a form or detail page: a header block followed by
/// several field-height rows.
class FormSkeleton extends StatelessWidget {
  final int rows;

  const FormSkeleton({super.key, this.rows = 4});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.pagePadding,
        children: [
          const SkeletonBox(width: 200, height: 24),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < rows; i++) ...[
            const SkeletonBox(height: 56, radius: AppSpacing.radiusMd),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
