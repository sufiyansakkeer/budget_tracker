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
  /// against [background], by moving lightness toward the opposite end.
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

    final hsl = HSLColor.fromColor(color);
    // A dark background needs a lighter accent and vice versa. Walking
    // lightness toward that end raises contrast monotonically, so a binary
    // search finds the smallest change that satisfies [minRatio].
    final target = luminance(background) < 0.5 ? 1.0 : 0.0;
    Color at(double t) => hsl
        .withLightness(hsl.lightness + (target - hsl.lightness) * t)
        .toColor();

    var lo = 0.0; // the original colour: known to fail
    var hi = 1.0; // pure white or black: passes against any real background
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
