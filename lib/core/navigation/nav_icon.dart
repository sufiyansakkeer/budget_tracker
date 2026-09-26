import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import 'nav_destination.dart';
import 'nav_icon_mode.dart';
import 'rive_nav_icon.dart';

/// The icon of one navigation destination.
///
/// Picks the renderer from [NavIconMode] and applies the shared selection
/// treatment (tint lerp and a slight scale) so Rive and Material icons look
/// identical in every respect but motion.
class NavIcon extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final reduced = AppMotion.isReduced(context);
    final renderer = NavIconMode.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1 : 0),
      duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
      curve: AppMotion.emphasizedDecelerate,
      builder: (context, t, _) {
        final color = Color.lerp(unselectedColor, selectedColor, t)!;
        final scale = 1 + (AppMotion.navIconSelectedScale - 1) * t;
        final material = _MaterialNavIcon(
          outlined: destination.icon,
          filled: destination.selectedIcon,
          progress: t,
          color: color,
          size: size,
        );
        final child = renderer == NavIconRenderer.material
            ? material
            : RiveNavIcon(
                spec: destination.rive,
                color: color,
                size: size,
                selected: selected,
                pulseToken: pulseToken,
                reduceMotion: reduced,
                fallback: material,
              );
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

/// Cross-fades the outlined glyph into its filled twin as [progress] goes
/// 0 → 1. Used as the Material renderer and as the Rive loading fallback.
class _MaterialNavIcon extends StatelessWidget {
  final IconData outlined;
  final IconData filled;
  final double progress;
  final Color color;
  final double size;

  const _MaterialNavIcon({
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
