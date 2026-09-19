import 'package:flutter/widgets.dart';

/// Central motion tokens for Monivo.
///
/// Fast interaction ≈150–250 ms · Standard transition ≈250–350 ms ·
/// Emphasis ≈350–500 ms. Curves are deliberately gentle so the app feels
/// calm rather than bouncy.
class AppMotion {
  AppMotion._();

  // Durations
  /// Button press feedback, chip selection, small state toggles.
  static const Duration fast = Duration(milliseconds: 150);

  /// Default for implicit animations (AnimatedContainer, AnimatedSwitcher).
  static const Duration standard = Duration(milliseconds: 250);

  /// Screen-level cross-fades and expanding/collapsing sections.
  static const Duration medium = Duration(milliseconds: 350);

  /// Number count-ups and progress bar sweeps.
  static const Duration emphasized = Duration(milliseconds: 450);

  /// Entrance stagger step between consecutive list items.
  static const Duration staggerStep = Duration(milliseconds: 40);

  /// Skeleton shimmer sweep.
  static const Duration shimmer = Duration(milliseconds: 1400);

  // Curves
  /// General purpose curve — quick start, soft landing.
  static const Curve standardCurve = Curves.easeOutCubic;

  /// For elements entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// For elements leaving the screen.
  static const Curve exit = Curves.easeInCubic;

  /// For values (money, percentages) changing in place.
  static const Curve value = Curves.easeInOutCubic;

  /// Material 3 emphasized curve for larger transitions.
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;

  /// Returns [duration] or [Duration.zero] when the platform asks to reduce
  /// motion, so animations degrade gracefully for accessibility.
  static Duration respectReducedMotion(
    BuildContext context,
    Duration duration,
  ) {
    return MediaQuery.maybeDisableAnimationsOf(context) == true
        ? Duration.zero
        : duration;
  }
}
