import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/default_categories.dart';
import 'package:monivo/core/theme/color_palettes.dart';
import 'package:monivo/core/theme/contrast.dart';
import 'package:monivo/features/categories/domain/entities/category_catalog.dart';
import 'package:monivo/features/expenses/presentation/widgets/category_visuals.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';

/// UX-088: the default categories shipped near-duplicate colours (Food and
/// Bills, Grocery and EMI, Salary Adjustment and Others). Every screen draws a
/// category colour through `CategoryVisuals.adaptiveColor`, which darkens it
/// on a light surface and lightens it on a dark one until it reaches 4.5:1,
/// and that clamp pulls similar hues together. So the check is on the colour
/// as drawn, on every palette's light and dark surface.
void main() {
  /// Below this CIEDE2000 distance two category marks read as the same colour
  /// at icon and bar size.
  const minDistance = 15.0;

  final surfaces = <(String, Color)>[
    for (final palette in ColorPalette.values)
      for (final scheme in [
        getPaletteColors(palette).lightScheme,
        getPaletteColors(palette).darkScheme,
      ])
        ('${palette.name}/${scheme.brightness.name}', scheme.surface),
  ];

  /// What `CategoryVisuals.adaptiveColor` returns on [surface].
  Color drawn(String hex, Color surface) =>
      Contrast.ensureContrast(CategoryVisuals.colorFor(hex), surface);

  test('no two default categories are drawn in near-identical colours', () {
    final failures = <String>[];
    for (var i = 0; i < defaultCategoryRows.length; i++) {
      for (var j = i + 1; j < defaultCategoryRows.length; j++) {
        final a = defaultCategoryRows[i];
        final b = defaultCategoryRows[j];
        for (final (name, surface) in surfaces) {
          final d = ciede2000(
            drawn(a.colorHex, surface),
            drawn(b.colorHex, surface),
          );
          if (d < minDistance) {
            failures.add(
              '${a.id}/${b.id} on $name: ΔE ${d.toStringAsFixed(1)}',
            );
          }
        }
      }
    }
    expect(failures, isEmpty);
  });

  test('every default colour is drawn at AA on every surface', () {
    for (final row in defaultCategoryRows) {
      for (final (name, surface) in surfaces) {
        expect(
          Contrast.ratio(drawn(row.colorHex, surface), surface),
          greaterThanOrEqualTo(Contrast.text),
          reason: '${row.id} on $name',
        );
      }
    }
  });

  test('every default colour is offered by the colour picker', () {
    // Otherwise editing a built-in category shows no colour selected.
    for (final row in defaultCategoryRows) {
      expect(
        CategoryCatalog.colorHexes,
        contains(row.colorHex),
        reason: row.id,
      );
    }
  });

  test('the colours replaced in v10 are the ones v9 shipped', () {
    // The v10 migration recolours a built-in category only while it still
    // has its v9 colour; every replaced colour must differ from the new one.
    final current = {for (final r in defaultCategoryRows) r.id: r.colorHex};
    expect(v9DefaultCategoryColours, isNotEmpty);
    for (final MapEntry(key: id, value: old)
        in v9DefaultCategoryColours.entries) {
      expect(current, contains(id));
      expect(current[id], isNot(old), reason: id);
    }
  });

  group('ciede2000', () {
    // Reference pairs from Sharma, Wu & Dalal (2005), converted from Lab.
    test('is zero for identical colours and symmetric', () {
      const a = Color(0xFF10AC84);
      const b = Color(0xFF1DD1A1);
      expect(ciede2000(a, a), closeTo(0, 1e-9));
      expect(ciede2000(a, b), closeTo(ciede2000(b, a), 1e-9));
    });

    test('matches the published Lab test data', () {
      expect(
        _de2000Lab(50, 2.6772, -79.7751, 50, 0, -82.7485),
        closeTo(2.0425, 1e-4),
      );
      expect(
        _de2000Lab(50, -1.3802, -84.2814, 50, 0, -82.7485),
        closeTo(1.0000, 1e-4),
      );
      expect(_de2000Lab(50, 0, 0, 50, -1, 2), closeTo(2.3669, 1e-4));
      expect(_de2000Lab(50, 2.5, 0, 50, 3.1736, 0.5854), closeTo(1.0000, 1e-4));
      expect(
        _de2000Lab(60.2574, -34.0099, 36.2677, 60.4626, -34.1751, 39.4387),
        closeTo(1.2644, 1e-4),
      );
      expect(
        _de2000Lab(22.7233, 20.0904, -46.694, 23.0331, 14.973, -42.5619),
        closeTo(2.0373, 1e-4),
      );
    });
  });
}

/// CIEDE2000 colour difference between two opaque sRGB colours (D65).
double ciede2000(Color a, Color b) {
  final (l1, a1, b1) = _lab(a);
  final (l2, a2, b2) = _lab(b);
  return _de2000Lab(l1, a1, b1, l2, a2, b2);
}

(double, double, double) _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r);
  final g = lin(c.g);
  final b = lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)));
}

double _de2000Lab(
  double l1,
  double a1,
  double b1,
  double l2,
  double a2,
  double b2,
) {
  double rad(double d) => d * math.pi / 180;
  double deg(double r) => r * 180 / math.pi;
  final c1 = math.sqrt(a1 * a1 + b1 * b1);
  final c2 = math.sqrt(a2 * a2 + b2 * b2);
  final cBar = (c1 + c2) / 2;
  final cBar7 = math.pow(cBar, 7);
  final g = 0.5 * (1 - math.sqrt(cBar7 / (cBar7 + math.pow(25, 7))));
  final a1p = (1 + g) * a1;
  final a2p = (1 + g) * a2;
  final c1p = math.sqrt(a1p * a1p + b1 * b1);
  final c2p = math.sqrt(a2p * a2p + b2 * b2);
  double hue(double b, double a) {
    if (a == 0 && b == 0) return 0;
    final h = deg(math.atan2(b, a));
    return h < 0 ? h + 360 : h;
  }

  final h1p = hue(b1, a1p);
  final h2p = hue(b2, a2p);
  final dLp = l2 - l1;
  final dCp = c2p - c1p;
  var dhp = 0.0;
  if (c1p * c2p != 0) {
    dhp = h2p - h1p;
    if (dhp > 180) dhp -= 360;
    if (dhp < -180) dhp += 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dhp / 2));
  final lBarP = (l1 + l2) / 2;
  final cBarP = (c1p + c2p) / 2;
  var hBarP = h1p + h2p;
  if (c1p * c2p != 0) {
    hBarP = (h1p - h2p).abs() <= 180
        ? (h1p + h2p) / 2
        : (h1p + h2p < 360 ? (h1p + h2p + 360) / 2 : (h1p + h2p - 360) / 2);
  }
  final t =
      1 -
      0.17 * math.cos(rad(hBarP - 30)) +
      0.24 * math.cos(rad(2 * hBarP)) +
      0.32 * math.cos(rad(3 * hBarP + 6)) -
      0.20 * math.cos(rad(4 * hBarP - 63));
  final dTheta = 30 * math.exp(-math.pow((hBarP - 275) / 25, 2));
  final cBarP7 = math.pow(cBarP, 7);
  final rc = 2 * math.sqrt(cBarP7 / (cBarP7 + math.pow(25, 7)));
  final sl =
      1 +
      0.015 * math.pow(lBarP - 50, 2) / math.sqrt(20 + math.pow(lBarP - 50, 2));
  final sc = 1 + 0.045 * cBarP;
  final sh = 1 + 0.015 * cBarP * t;
  final rt = -math.sin(rad(2 * dTheta)) * rc;
  return math.sqrt(
    math.pow(dLp / sl, 2) +
        math.pow(dCp / sc, 2) +
        math.pow(dHp / sh, 2) +
        rt * (dCp / sc) * (dHp / sh),
  );
}
