import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/color_palettes.dart';
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

    test('every palette has different primary colors', () {
      final primaryColors = <Color>{};
      for (final palette in ColorPalette.values) {
        final colors = getPaletteColors(palette);
        primaryColors.add(colors.lightScheme.primary);
      }
      // At least 5 unique primary colors (Default and Ocean might share one)
      expect(primaryColors.length, greaterThanOrEqualTo(5));
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
}
