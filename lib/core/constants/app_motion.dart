import 'package:flutter/widgets.dart';

/// Central motion tokens for Monivo.
///
/// One motion language for the whole app:
/// * Micro interaction ≈120–150 ms (press, chip, icon crossfade)
/// * Small component transition ≈250 ms (state switches, indicators)
/// * Screen transition ≈300–350 ms (routes, tabs, sections)
/// * Complex reveal ≈450 ms (number count-ups, progress sweeps, charts)
///
/// Curves are deliberately gentle so the app feels calm rather than bouncy.
/// Every animation should go through [respectReducedMotion] (or check
/// [isReduced]) so the app degrades gracefully for accessibility.
class AppMotion {
  AppMotion._();

  // ── Durations ─────────────────────────────────────────────────────────

  /// Press feedback, icon crossfades, tiny scale changes.
  static const Duration micro = Duration(milliseconds: 120);

  /// Chip selection, small state toggles, label fades.
  static const Duration fast = Duration(milliseconds: 150);

  /// Default for implicit animations (AnimatedContainer, AnimatedSwitcher).
  static const Duration standard = Duration(milliseconds: 250);

  /// Screen-level cross-fades and expanding/collapsing sections.
  static const Duration medium = Duration(milliseconds: 350);

  /// Number count-ups, progress bar sweeps and chart reveals.
  static const Duration emphasized = Duration(milliseconds: 450);

  /// Route push. Pops use [standard] so going back feels snappier.
  static const Duration page = Duration(milliseconds: 300);

  /// Modal bottom sheet entrance; [sheetExit] is used when dismissing.
  static const Duration sheet = Duration(milliseconds: 300);
  static const Duration sheetExit = Duration(milliseconds: 220);

  /// Dialog entrance and exit.
  static const Duration dialog = Duration(milliseconds: 220);

  /// Entrance stagger step between consecutive list items.
  static const Duration staggerStep = Duration(milliseconds: 40);

  /// Skeleton shimmer sweep.
  static const Duration shimmer = Duration(milliseconds: 1400);

  // ── Curves ────────────────────────────────────────────────────────────

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

  /// Material 3 "emphasized decelerate": for things arriving on screen.
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Material 3 "emphasized accelerate": for things leaving the screen.
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  // ── Scales ────────────────────────────────────────────────────────────

  /// Scale applied to cards and buttons while pressed. Close to 1 on
  /// purpose — a hint, not a bounce.
  static const double pressedScale = 0.98;

  /// Scale of the selected bottom-navigation icon.
  static const double navIconSelectedScale = 1.1;

  // ── Accessibility ─────────────────────────────────────────────────────

  /// True when the platform asks to reduce motion.
  ///
  /// Reads the nearest [MediaQuery]; above the app's [MediaQuery] (e.g. in
  /// `MaterialApp` construction) it falls back to the platform setting.
  static bool isReduced(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
  }

  /// Returns [duration] or [Duration.zero] when the platform asks to reduce
  /// motion, so animations degrade gracefully for accessibility.
  static Duration respectReducedMotion(
    BuildContext context,
    Duration duration,
  ) {
    return isReduced(context) ? Duration.zero : duration;
  }
}
