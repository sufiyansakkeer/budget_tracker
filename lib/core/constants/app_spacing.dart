import 'package:flutter/material.dart';

/// Central spacing & radius scale for Monivo.
///
/// Prefer these tokens over ad-hoc margins so the whole app shares one
/// consistent rhythm (4 → 8 → 12 → 16 → 20 → 24 → 32 → 48).
class AppSpacing {
  AppSpacing._();

  // Spacing Units
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double smd = 12.0;
  static const double md = 16.0;
  static const double mlg = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Border Radii
  /// Tiny radius for chips, tags and drag handles.
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusSmd = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusFull = 999.0;

  // Edge Insets Shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingSmd = EdgeInsets.all(smd);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(
    horizontal: md,
  );
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(
    horizontal: lg,
  );

  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(
    vertical: sm,
  );
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(
    vertical: md,
  );

  /// Standard page padding for scrollable screens.
  static const EdgeInsets pagePadding = EdgeInsets.all(md);

  /// Page padding that also leaves room for a floating action button.
  static const EdgeInsets pagePaddingWithFab = EdgeInsets.fromLTRB(
    md,
    md,
    md,
    AppSizes.fabClearance,
  );

  // Border Radius Shortcuts
  static final BorderRadius borderRadiusXs = BorderRadius.circular(radiusXs);
  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusSmd = BorderRadius.circular(radiusSmd);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static final BorderRadius borderRadiusFull = BorderRadius.circular(
    radiusFull,
  );
}

/// Component dimensions shared across the app.
class AppSizes {
  AppSizes._();

  /// Minimum accessible touch target.
  static const double touchTarget = 48.0;

  // Icon sizes
  static const double iconXs = 14.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;
  static const double iconHero = 48.0;

  // Leading icon containers (avatars / tiles)
  static const double avatarSm = 36.0;
  static const double avatarMd = 44.0;
  static const double avatarLg = 56.0;
  static const double avatarXl = 96.0;

  // Progress indicators
  static const double progressThin = 4.0;
  static const double progressSm = 6.0;
  static const double progressMd = 8.0;
  static const double progressLg = 10.0;
  static const double ringSm = 64.0;
  static const double ringMd = 80.0;

  /// Width of the drag handle on bottom sheets.
  static const double dragHandleWidth = 40.0;
  static const double dragHandleHeight = 4.0;

  /// Maximum width of centered page content on large screens.
  static const double contentMaxWidth = 640.0;

  /// Bottom padding that keeps the last list item clear of an extended FAB.
  static const double fabClearance = 96.0;

  /// Height of the bottom navigation bar.
  static const double navBarHeight = 68.0;

  /// Height of a standard chart area.
  static const double chartHeight = 200.0;
  static const double chartHeightSm = 140.0;
}
