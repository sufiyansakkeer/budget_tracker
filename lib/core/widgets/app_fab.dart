import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import 'pressable.dart';

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

  const AppFab({
    super.key,
    required this.heroTag,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tooltip,
    this.animateEntrance = true,
  });

  @override
  Widget build(BuildContext context) {
    final fab = Pressable(
      enabled: onPressed != null,
      pressedScale: 0.95,
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        tooltip: tooltip,
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
