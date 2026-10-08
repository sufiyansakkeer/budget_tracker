import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import 'pressable.dart';
import 'app_animated_size.dart';

/// The app's extended floating action button.
///
/// Scales and fades in once when it appears, and presses in slightly when
/// tapped, so the primary action feels alive without competing with the
/// bottom navigation bar. Reduced-motion settings skip the entrance.
class AppFab extends StatelessWidget {
  final Object heroTag;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String? tooltip;

  /// Plays the scale-and-fade entrance on first build. Pass false when the
  /// button is added to a [Scaffold] after its first frame: the scaffold
  /// then animates the button in itself and a second entrance would stack.
  final bool animateEntrance;

  /// Shows the label. Screens collapse it to the icon while the user scrolls
  /// down a list, so the button covers less of the right-aligned amounts.
  final bool extended;

  const AppFab({
    super.key,
    required this.heroTag,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tooltip,
    this.animateEntrance = true,
    this.extended = true,
  });

  @override
  Widget build(BuildContext context) {
    final fab = Pressable(
      enabled: onPressed != null,
      pressedScale: AppMotion.pressedScale,
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        icon: Icon(icon),
        // The label folds away instead of snapping, so the button shrinks to
        // its icon in one movement.
        label: AppAnimatedSize(
          duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
          curve: AppMotion.standardCurve,
          child: extended ? Text(label) : const SizedBox.shrink(),
        ),
        extendedIconLabelSpacing: extended ? null : 0,
        tooltip: tooltip ?? label,
      ),
    );

    if (!animateEntrance || AppMotion.isReduced(context)) return fab;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.medium,
      curve: AppMotion.emphasizedDecelerate,
      child: fab,
      builder: (context, t, child) {
        if (t >= 1) return child!;
        return Transform.scale(
          scale: 0.8 + 0.2 * t,
          child: Opacity(opacity: t, child: child),
        );
      },
    );
  }
}
