import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/color_palettes.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/core/theme/contrast.dart';
import 'package:monivo/features/categories/domain/entities/category_catalog.dart';
import 'package:monivo/features/expenses/presentation/widgets/category_visuals.dart';

void main() {
  group('Contrast.ratio', () {
    test('matches the WCAG reference values', () {
      expect(Contrast.ratio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(Contrast.ratio(Colors.white, Colors.white), closeTo(1, 0.001));
      // #767676 on white is the canonical "just passes AA" grey.
      expect(
        Contrast.ratio(const Color(0xFF767676), Colors.white),
        closeTo(4.54, 0.05),
      );
    });

    test('is symmetric', () {
      const a = Color(0xFF1DD1A1);
      const b = Color(0xFFFFFFFF);
      expect(Contrast.ratio(a, b), closeTo(Contrast.ratio(b, a), 0.0001));
    });
  });

  group('Contrast.ensureContrast', () {
    test('leaves a colour that already passes untouched', () {
      const dark = Color(0xFF1A1A1A);
      expect(Contrast.ensureContrast(dark, Colors.white), dark);
    });

    test('darkens a bright accent on a light surface', () {
      const bright = Color(0xFF00D2D3); // 1.79:1 on white
      final fixed = Contrast.ensureContrast(bright, Colors.white);
      expect(Contrast.ratio(fixed, Colors.white), greaterThanOrEqualTo(4.5));
      expect(
        Contrast.ratio(fixed, Colors.white),
        lessThan(8),
        reason: 'it stops as soon as the ratio is met, not at black',
      );
    });

    test('keeps the hue so the colour still reads as itself', () {
      const green = Color(0xFF10AC84); // 2.75:1 on white
      final fixed = Contrast.ensureContrast(green, Colors.white);
      expect(
        HSLColor.fromColor(fixed).hue,
        closeTo(HSLColor.fromColor(green).hue, 2),
      );
      expect(Contrast.ratio(fixed, Colors.white), greaterThanOrEqualTo(4.5));
    });

    test('lightens a dark accent on a dark surface', () {
      const deep = Color(0xFF5F27CD);
      const darkSurface = Color(0xFF121212);
      final fixed = Contrast.ensureContrast(deep, darkSurface);
      expect(Contrast.ratio(fixed, darkSurface), greaterThanOrEqualTo(4.5));
    });

    test('honours a lower ratio for large text', () {
      const bright = Color(0xFFFECA57);
      final large = Contrast.ensureContrast(
        bright,
        Colors.white,
        minRatio: Contrast.large,
      );
      expect(Contrast.ratio(large, Colors.white), greaterThanOrEqualTo(3.0));
      // A looser requirement keeps more of the original lightness.
      final strict = Contrast.ensureContrast(bright, Colors.white);
      expect(
        HSLColor.fromColor(large).lightness,
        greaterThan(HSLColor.fromColor(strict).lightness),
      );
    });
  });

  group('theme text tokens', () {
    test('supporting text meets AA in every palette and mode', () {
      for (final palette in ColorPalette.values) {
        final colors = getPaletteColors(palette);
        for (final brightness in Brightness.values) {
          final tokens = AppColorTokens.fromPalette(palette, brightness);
          final scheme = brightness == Brightness.dark
              ? colors.darkScheme
              : colors.lightScheme;
          expect(
            Contrast.ratio(tokens.textSecondary, scheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'textSecondary in $palette/$brightness',
          );
          expect(
            Contrast.ratio(tokens.textTertiary, scheme.surface),
            greaterThanOrEqualTo(3.0),
            reason: 'textTertiary in $palette/$brightness',
          );
          expect(
            Contrast.ratio(tokens.textPrimary, scheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'textPrimary in $palette/$brightness',
          );
        }
      }
    });
  });

  group('category colours are legible in every palette', () {
    test('every catalogue colour reaches AA on every surface', () {
      for (final palette in ColorPalette.values) {
        final colors = getPaletteColors(palette);
        for (final scheme in [colors.lightScheme, colors.darkScheme]) {
          for (final hex in CategoryCatalog.colorHexes) {
            final adjusted = Contrast.ensureContrast(
              CategoryVisuals.colorFor(hex),
              scheme.surface,
            );
            expect(
              Contrast.ratio(adjusted, scheme.surface),
              greaterThanOrEqualTo(4.5),
              reason: '$hex on ${scheme.brightness} surface of $palette',
            );
          }
        }
      }
    });

    testWidgets('adaptiveColor applies it against the current surface', (
      tester,
    ) async {
      final scheme = getPaletteColors(ColorPalette.ocean).lightScheme;
      late Color adaptive;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Builder(
            builder: (context) {
              adaptive = CategoryVisuals.adaptiveColor(context, '#00D2D3');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        Contrast.ratio(adaptive, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
