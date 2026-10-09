import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import 'nav_destination.dart';

/// The icon of one navigation destination.
///
/// The outlined glyph cross-fades into its filled twin while the tint lerps
/// and the icon scales up slightly, so selection reads as one movement.
/// Re-tapping the selected tab ([pulseToken] changes) plays a short pulse.
/// Under reduced motion every change is instant and the pulse is skipped.
class NavIcon extends StatefulWidget {
  final AppNavDestination destination;
  final bool selected;
  final int pulseToken;
  final Color selectedColor;
  final Color unselectedColor;
  final double size;

  const NavIcon({
    super.key,
    required this.destination,
    required this.selected,
    required this.pulseToken,
    required this.selectedColor,
    required this.unselectedColor,
    required this.size,
  });

  @override
  State<NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<NavIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  );

  /// 1 → 1.12 → 1: a quick bump that settles, never a bounce.
  late final Animation<double> _pulseScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.12,
      ).chain(CurveTween(curve: AppMotion.emphasizedDecelerate)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.12,
        end: 1.0,
      ).chain(CurveTween(curve: AppMotion.standardCurve)),
      weight: 60,
    ),
  ]).animate(_pulse);

  @override
  void didUpdateWidget(covariant NavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameSelected = widget.selected && !oldWidget.selected;
    final reTapped = widget.pulseToken != oldWidget.pulseToken;
    if ((becameSelected || reTapped) && !AppMotion.isReduced(context)) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.selected ? 1 : 0),
      duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
      curve: AppMotion.emphasizedDecelerate,
      builder: (context, t, _) {
        final color = Color.lerp(
          widget.unselectedColor,
          widget.selectedColor,
          t,
        )!;
        final scale = 1 + (AppMotion.navIconSelectedScale - 1) * t;
        return ScaleTransition(
          scale: _pulseScale,
          child: Transform.scale(
            scale: scale,
            child: _CrossFadeIcon(
              outlined: widget.destination.icon,
              filled: widget.destination.selectedIcon,
              progress: t,
              color: color,
              size: widget.size,
            ),
          ),
        );
      },
    );
  }
}

/// Cross-fades the outlined glyph into its filled twin as [progress] goes
/// 0 → 1.
class _CrossFadeIcon extends StatelessWidget {
  final IconData outlined;
  final IconData filled;
  final double progress;
  final Color color;
  final double size;

  const _CrossFadeIcon({
    required this.outlined,
    required this.filled,
    required this.progress,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 1 - progress,
              child: Icon(outlined, size: size, color: color),
            ),
            Opacity(
              opacity: progress,
              child: Icon(filled, size: size, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
