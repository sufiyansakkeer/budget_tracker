import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';

/// Wraps skeleton placeholders in a single, shared shimmer sweep.
///
/// One [AnimationController] drives every [SkeletonBox] beneath it, so a whole
/// loading layout costs one ticker. Honors reduced-motion settings by
/// rendering static placeholders.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

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
    if (_reduced) {
      return widget.child;
    }
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHigh;
    final highlight = theme.brightness == Brightness.dark
        ? Color.lerp(base, theme.colorScheme.surface, -0.25)!
        : Color.lerp(base, Colors.white, 0.6)!;

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

/// A single skeleton row shaped like a list tile (avatar + two lines + amount).
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.smd),
      child: Row(
        children: [
          SkeletonBox(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            radius: AppSpacing.radiusSmd,
          ),
          SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 14),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 90, height: 12),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.smd),
          SkeletonBox(width: 64, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton layout for the dashboard while loading.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.pagePadding,
        children: const [
          // Greeting + budget chip
          SkeletonBox(width: 180, height: 20),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: 220, height: 36, radius: AppSpacing.radiusFull),
          SizedBox(height: AppSpacing.lg),
          // Hero card
          SkeletonBox(height: 220, radius: AppSpacing.radiusLg),
          SizedBox(height: AppSpacing.md),
          // Overview row
          Row(
            children: [
              Expanded(
                child: SkeletonBox(height: 96, radius: AppSpacing.radiusLg),
              ),
              SizedBox(width: AppSpacing.smd),
              Expanded(
                child: SkeletonBox(height: 96, radius: AppSpacing.radiusLg),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          // Recent list
          SkeletonBox(width: 160, height: 18),
          SizedBox(height: AppSpacing.xs),
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
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
