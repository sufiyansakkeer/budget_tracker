import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG contrast helpers.
///
/// Accent colours in this app come from two places that are chosen for
/// identity rather than legibility: the palette's semantic tokens (success,
/// warning, info, tertiary) and the per-category colours a user picks. Drawing
/// text in those colours on a light surface routinely lands between 1.5:1 and
/// 3:1, well under the 4.5:1 that WCAG asks for body text.
///
/// [ensureContrast] keeps the hue — so the colour still reads as "that
/// category" or "a warning" — and moves only lightness until the ratio is met.
abstract final class Contrast {
  /// Minimum ratio for normal-size text (WCAG AA).
  static const double text = 4.5;

  /// Minimum ratio for large text and meaningful non-text marks (WCAG AA).
  static const double large = 3.0;

  /// Relative luminance per WCAG 2.x.
  static double luminance(Color color) => color.computeLuminance();

  /// Contrast ratio between two opaque colours: 1.0 (identical) to 21.0.
  static double ratio(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Returns [color], or the nearest variant of it that reaches [minRatio]
  /// against [background], by moving lightness away from the background.
  ///
  /// The colour keeps its own side of the background: a foreground that is
  /// already darker than the background is darkened, one that is lighter is
  /// lightened. That matters on mid-tone fills (a button in dark mode, a
  /// tinted chip) where a dark label must stay dark rather than being pushed
  /// through the fill toward white. Only if that side cannot reach the ratio
  /// at all is the other end used.
  ///
  /// Hue and saturation are preserved. If even pure black or white cannot
  /// reach the ratio (impossible for a real background), the closest attempt
  /// is returned rather than throwing.
  static Color ensureContrast(
    Color color,
    Color background, {
    double minRatio = text,
  }) {
    if (ratio(color, background) >= minRatio) return color;

    final own = luminance(color) < luminance(background) ? 0.0 : 1.0;
    final preferred = _towards(color, background, own, minRatio);
    if (preferred != null) return preferred;
    return _towards(color, background, 1 - own, minRatio) ??
        HSLColor.fromColor(color).withLightness(1 - own).toColor();
  }

  /// Walks [color]'s lightness toward [target] (0 = black, 1 = white) and
  /// returns the smallest change that reaches [minRatio] on [background], or
  /// null when even the extreme cannot.
  static Color? _towards(
    Color color,
    Color background,
    double target,
    double minRatio,
  ) {
    final hsl = HSLColor.fromColor(color);
    Color at(double t) => hsl
        .withLightness(hsl.lightness + (target - hsl.lightness) * t)
        .toColor();

    // Moving lightness toward one end raises contrast monotonically, so a
    // binary search finds the smallest change that satisfies [minRatio].
    if (ratio(at(1), background) < minRatio) return null;
    var lo = 0.0; // the original colour: known to fail
    var hi = 1.0; // the extreme: known to pass
    var best = at(1);
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      final candidate = at(mid);
      if (ratio(candidate, background) >= minRatio) {
        best = candidate;
        hi = mid; // keep as much of the original colour as possible
      } else {
        lo = mid;
      }
    }
    return best;
  }
}

/// Convenience: resolve an accent for text on the current surface.
extension ContrastOnContext on BuildContext {
  /// [accent] adjusted until it is legible as text on this theme's surface.
  Color readable(Color accent, {double minRatio = Contrast.text}) {
    return Contrast.ensureContrast(
      accent,
      Theme.of(this).colorScheme.surface,
      minRatio: minRatio,
    );
  }
}
