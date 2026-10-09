import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/color_palettes.dart';
import 'package:monivo/core/theme/contrast.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ColorPalette entity', () {
    test('fromString parses valid palette names', () {
      expect(
        ColorPalette.fromString('defaultPalette'),
        ColorPalette.defaultPalette,
      );
      expect(ColorPalette.fromString('ocean'), ColorPalette.ocean);
      expect(ColorPalette.fromString('forest'), ColorPalette.forest);
      expect(ColorPalette.fromString('sunset'), ColorPalette.sunset);
      expect(ColorPalette.fromString('violet'), ColorPalette.violet);
      expect(ColorPalette.fromString('rose'), ColorPalette.rose);
    });

    test('the eight stored palette names are unchanged', () {
      // Settings store the palette by name; renaming one would silently
      // reset everyone who chose it back to Default on the next launch.
      expect(
        ColorPalette.values.map((p) => p.name),
        unorderedEquals([
          'defaultPalette',
          'ocean',
          'blossomVapor',
          'mahoganyBlaze',
          'forest',
          'sunset',
          'violet',
          'rose',
        ]),
      );
      for (final palette in ColorPalette.values) {
        expect(ColorPalette.fromString(palette.name), palette);
      }
    });

    test('fromString returns defaultPalette for null', () {
      expect(ColorPalette.fromString(null), ColorPalette.defaultPalette);
    });

    test('fromString returns defaultPalette for unknown string', () {
      expect(ColorPalette.fromString('unknown'), ColorPalette.defaultPalette);
    });

    test('all palettes have a display option', () {
      for (final palette in ColorPalette.values) {
        expect(
          paletteOptions.any((o) => o.palette == palette),
          isTrue,
          reason: 'Missing display option for $palette',
        );
      }
    });
  });

  group('PaletteColors', () {
    test('every palette provides distinct light and dark ColorSchemes', () {
      for (final palette in ColorPalette.values) {
        final colors = getPaletteColors(palette);
        expect(
          colors.lightScheme.brightness,
          Brightness.light,
          reason: '$palette light scheme must be light brightness',
        );
        expect(
          colors.darkScheme.brightness,
          Brightness.dark,
          reason: '$palette dark scheme must be dark brightness',
        );
      }
    });

    test('every palette has its own primary in light and dark', () {
      for (final brightness in Brightness.values) {
        final primaries = {
          for (final palette in ColorPalette.values)
            AppColorTokens.fromPalette(palette, brightness).primary,
        };
        expect(
          primaries,
          hasLength(ColorPalette.values.length),
          reason: 'two palettes share a ${brightness.name} primary',
        );
      }
    });

    test('semantic colors are distinct from primary in each palette', () {
      for (final palette in ColorPalette.values) {
        final colors = getPaletteColors(palette);
        // Income and expense should be different colors
        expect(
          colors.incomeLight != colors.expenseLight,
          isTrue,
          reason: '$palette: income and expense should differ (light)',
        );
        expect(
          colors.incomeDark != colors.expenseDark,
          isTrue,
          reason: '$palette: income and expense should differ (dark)',
        );
      }
    });

    test('palette accessor methods return correct brightness variant', () {
      for (final palette in ColorPalette.values) {
        final colors = getPaletteColors(palette);
        expect(
          colors.income(Brightness.light),
          colors.incomeLight,
          reason: '$palette: income(light) should match incomeLight',
        );
        expect(
          colors.income(Brightness.dark),
          colors.incomeDark,
          reason: '$palette: income(dark) should match incomeDark',
        );
      }
    });
  });

  group('AppTheme', () {
    test('buildLightTheme and buildDarkTheme return valid ThemeData', () {
      for (final palette in ColorPalette.values) {
        final light = AppTheme.buildLightTheme(palette);
        final dark = AppTheme.buildDarkTheme(palette);

        expect(light.brightness, Brightness.light);
        expect(dark.brightness, Brightness.dark);

        expect(light.useMaterial3, isTrue);
        expect(dark.useMaterial3, isTrue);
      }
    });

    test('Ocean + Light has different primary than Ocean + Dark', () {
      final light = AppTheme.buildLightTheme(ColorPalette.ocean);
      final dark = AppTheme.buildDarkTheme(ColorPalette.ocean);

      // The ColorScheme should be different
      expect(light.colorScheme.primary, isNot(dark.colorScheme.primary));
    });

    test('Ocean + Light has different primary than Forest + Light', () {
      final ocean = AppTheme.buildLightTheme(ColorPalette.ocean);
      final forest = AppTheme.buildLightTheme(ColorPalette.forest);

      expect(ocean.colorScheme.primary, isNot(forest.colorScheme.primary));
    });

    test('default palette matches original app colors for primary', () {
      final light = AppTheme.buildLightTheme(ColorPalette.defaultPalette);
      expect(light.colorScheme.primary, const Color(0xFF3155D4));
    });

    test(
      'every palette + theme mode combination produces readable surfaces',
      () {
        for (final palette in ColorPalette.values) {
          final light = AppTheme.buildLightTheme(palette);
          final dark = AppTheme.buildDarkTheme(palette);

          // Surfaces should be non-null
          expect(light.colorScheme.surface, isNotNull);
          expect(dark.colorScheme.surface, isNotNull);

          // On-surface should be set
          expect(light.colorScheme.onSurface, isNotNull);
          expect(dark.colorScheme.onSurface, isNotNull);
        }
      },
    );

    test('legacy getters use default palette', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    });
  });

  group('AppColorTokens', () {
    test('fromPalette produces valid tokens for each palette', () {
      for (final palette in ColorPalette.values) {
        for (final brightness in Brightness.values) {
          final tokens = AppColorTokens.fromPalette(palette, brightness);
          // Verify no null/zero colors
          expect(tokens.primary, isNotNull);
          expect(tokens.secondary, isNotNull);
          expect(tokens.success, isNotNull);
          expect(tokens.warning, isNotNull);
          expect(tokens.error, isNotNull);
          expect(tokens.income, isNotNull);
          expect(tokens.expense, isNotNull);
        }
      }
    });

    test('lerp produces intermediate colors', () {
      final ocean = AppColorTokens.fromPalette(
        ColorPalette.ocean,
        Brightness.light,
      );
      final forest = AppColorTokens.fromPalette(
        ColorPalette.forest,
        Brightness.light,
      );

      final lerped = ocean.lerp(forest, 0.5);
      expect(lerped, isA<AppColorTokens>());
      // Lerped primary should be different from both inputs
      expect(lerped.primary, isNot(ocean.primary));
      expect(lerped.primary, isNot(forest.primary));
    });

    test('copyWith works correctly', () {
      final tokens = AppColorTokens.fromPalette(
        ColorPalette.defaultPalette,
        Brightness.light,
      );
      final modified = tokens.copyWith(primary: const Color(0xFF000000));
      expect(modified.primary, const Color(0xFF000000));
      expect(modified.secondary, tokens.secondary);
    });
  });

  group('Default palette preserves existing appearance', () {
    test('default palette light primary matches original', () {
      final colors = getPaletteColors(ColorPalette.defaultPalette);
      expect(colors.lightScheme.primary, const Color(0xFF3155D4));
      expect(colors.lightScheme.secondary, const Color(0xFF159A9C));
    });

    test('default palette dark primary is lighter than light', () {
      final colors = getPaletteColors(ColorPalette.defaultPalette);
      // Dark primary should be lighter/brighter
      final lightLuminance = colors.lightScheme.primary.computeLuminance();
      final darkLuminance = colors.darkScheme.primary.computeLuminance();
      expect(darkLuminance, greaterThan(lightLuminance));
    });
  });

  group('Palette design contract', () {
    ColorScheme schemeOf(ColorPalette p, Brightness b) => b == Brightness.light
        ? getPaletteColors(p).lightScheme
        : getPaletteColors(p).darkScheme;
    ThemeData themeOf(ColorPalette p, Brightness b) => b == Brightness.light
        ? AppTheme.buildLightTheme(p)
        : AppTheme.buildDarkTheme(p);

    for (final palette in ColorPalette.values) {
      for (final brightness in Brightness.values) {
        final where = '${palette.name}/${brightness.name}';

        // The contrast engine only moves a colour that misses a floor. A
        // palette authored at the floors is therefore shown exactly as it is
        // written, and the hex in color_palettes.dart is what users see.
        test('$where ships exactly as written', () {
          final authored = schemeOf(palette, brightness);
          final colors = getPaletteColors(palette);
          final built = themeOf(palette, brightness);
          final shipped = built.colorScheme;
          final tokens = built.extension<AppColorTokens>()!;
          final roles = <String, (Color, Color)>{
            'primary': (authored.primary, shipped.primary),
            'onPrimary': (authored.onPrimary, shipped.onPrimary),
            'onPrimaryContainer': (
              authored.onPrimaryContainer,
              shipped.onPrimaryContainer,
            ),
            'secondary': (authored.secondary, shipped.secondary),
            'onSecondary': (authored.onSecondary, shipped.onSecondary),
            'onSecondaryContainer': (
              authored.onSecondaryContainer,
              shipped.onSecondaryContainer,
            ),
            'tertiary': (authored.tertiary, shipped.tertiary),
            'onTertiary': (authored.onTertiary, shipped.onTertiary),
            'onTertiaryContainer': (
              authored.onTertiaryContainer,
              shipped.onTertiaryContainer,
            ),
            'error': (authored.error, shipped.error),
            'onError': (authored.onError, shipped.onError),
            'onErrorContainer': (
              authored.onErrorContainer,
              shipped.onErrorContainer,
            ),
            'surface': (authored.surface, shipped.surface),
            'income': (colors.income(brightness), tokens.income),
            'expense': (colors.expense(brightness), tokens.expense),
            'success': (colors.success(brightness), tokens.success),
            'warning': (colors.warning(brightness), tokens.warning),
            'info': (colors.info(brightness), tokens.info),
          };
          for (final MapEntry(key: role, value: (written, shown))
              in roles.entries) {
            expect(
              shown,
              written,
              reason:
                  '$where $role is written as '
                  '${written.toARGB32().toRadixString(16)} but the contrast '
                  'floors show ${shown.toARGB32().toRadixString(16)}; write '
                  'a colour that already meets them',
            );
          }
        });

        // Colour belongs to accents and selection. The page and the
        // container levels keep at most a cast of the palette's hue, so no
        // palette paints every card pink or navy.
        test('$where surfaces stay near-neutral', () {
          final tokens = AppColorTokens.fromPalette(palette, brightness);
          final levels = {
            'background': tokens.background,
            'card': tokens.card,
            'surfaceContainer': tokens.surfaceContainer,
            'surfaceContainerHigh': tokens.surfaceContainerHigh,
            'surfaceContainerHighest': tokens.surfaceContainerHighest,
          };
          for (final level in levels.entries) {
            expect(
              _channelSpread(level.value),
              lessThanOrEqualTo(20),
              reason: '$where ${level.key} reads as a colour',
            );
          }
        });

        test('$where gradient is a short sweep of the primary', () {
          final colors = getPaletteColors(palette);
          final start = colors.primaryGradientStart(brightness);
          final end = colors.primaryGradientEnd(brightness);
          final hueGap =
              (HSLColor.fromColor(start).hue - HSLColor.fromColor(end).hue)
                  .abs();
          expect(
            hueGap > 180 ? 360 - hueGap : hueGap,
            lessThanOrEqualTo(15),
            reason: '$where gradient changes hue',
          );
          expect(
            Contrast.ratio(start, end),
            lessThanOrEqualTo(1.8),
            reason: '$where gradient is a jump, not a sweep',
          );
        });

        // The tones the app draws status with must not be mistaken for the
        // brand: an "Over budget" chip beside a primary button has to read
        // as a different colour. Info is exempt (a neutral fact may share a
        // blue brand), and so are income/expense, which amounts never use.
        test('$where primary stays apart from the status tones', () {
          final tokens = AppColorTokens.fromPalette(palette, brightness);
          for (final status in {
            'error': tokens.error,
            'success': tokens.success,
            'warning': tokens.warning,
          }.entries) {
            expect(
              _deltaE(tokens.primary, status.value),
              greaterThanOrEqualTo(15),
              reason: '$where primary is close to ${status.key}',
            );
          }
        });
      }

      test('${palette.name} dark primary is lighter than light', () {
        expect(
          schemeOf(palette, Brightness.dark).primary.computeLuminance(),
          greaterThan(
            schemeOf(palette, Brightness.light).primary.computeLuminance(),
          ),
        );
      });
    }

    test('error, money and status colours are shared by every palette', () {
      for (final brightness in Brightness.values) {
        final reference = themeOf(ColorPalette.defaultPalette, brightness);
        final refTokens = reference.extension<AppColorTokens>()!;
        for (final palette in ColorPalette.values) {
          final theme = themeOf(palette, brightness);
          final c = theme.colorScheme;
          final t = theme.extension<AppColorTokens>()!;
          final where = '${palette.name}/${brightness.name}';
          expect(c.error, reference.colorScheme.error, reason: where);
          expect(c.onError, reference.colorScheme.onError, reason: where);
          expect(
            c.errorContainer,
            reference.colorScheme.errorContainer,
            reason: where,
          );
          expect(
            c.onErrorContainer,
            reference.colorScheme.onErrorContainer,
            reason: where,
          );
          expect(t.income, refTokens.income, reason: where);
          expect(t.expense, refTokens.expense, reason: where);
          expect(t.success, refTokens.success, reason: where);
          expect(t.warning, refTokens.warning, reason: where);
          expect(t.info, refTokens.info, reason: where);
        }
      }
    });

    test('money and status colours keep their hue family', () {
      // Income and success read as green, expense and error as red, warning
      // as amber and info as blue, in both themes.
      bool hueIn(Color c, double from, double to) {
        final hue = HSLColor.fromColor(c).hue;
        return from <= to ? hue >= from && hue <= to : hue >= from || hue <= to;
      }

      for (final brightness in Brightness.values) {
        final t = AppColorTokens.fromPalette(
          ColorPalette.defaultPalette,
          brightness,
        );
        final families = <String, (Color, double, double)>{
          'income': (t.income, 90, 170),
          'success': (t.success, 90, 170),
          'expense': (t.expense, 340, 20),
          'error': (t.error, 340, 20),
          'warning': (t.warning, 25, 50),
          'info': (t.info, 190, 240),
        };
        for (final MapEntry(key: role, value: (color, from, to))
            in families.entries) {
          expect(
            hueIn(color, from, to),
            isTrue,
            reason: '${brightness.name} $role has left its hue family',
          );
        }
      }
    });
  });
}

/// The largest difference between two RGB channels, on a 0-255 scale: 0 for
/// a pure grey, growing as a colour gets more chromatic.
int _channelSpread(Color c) {
  final channels = [c.r, c.g, c.b].map((v) => (v * 255).round()).toList()
    ..sort();
  return channels.last - channels.first;
}

/// CIE76 colour difference (CIELAB, D65). About 2 is just noticeable;
/// above 15, two swatches read as different colours at a glance.
double _deltaE(Color a, Color b) {
  List<double> lab(Color c) {
    double linear(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final r = linear(c.r), g = linear(c.g), b = linear(c.b);
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    double f(double t) =>
        t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
    return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
  }

  final p = lab(a), q = lab(b);
  return math.sqrt(
    math.pow(p[0] - q[0], 2) +
        math.pow(p[1] - q[1], 2) +
        math.pow(p[2] - q[2], 2),
  );
}
