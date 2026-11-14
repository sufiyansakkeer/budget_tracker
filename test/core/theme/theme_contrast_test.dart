import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/app_tone.dart';
import 'package:monivo/core/theme/contrast.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';

/// Guards the contrast contract of the built themes.
///
/// [AppColorTokens] promises that every colour the app draws text, icons,
/// outlines and navigation with is legible on the surfaces it is drawn on,
/// for every palette in both light and dark. This test checks the *built*
/// [ThemeData] — the ColorScheme and component themes widgets actually
/// resolve — so a palette edit or a theme-builder change that silently
/// breaks legibility fails here, not on a device.
void main() {
  Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

  void expectRatio(Color fg, Color bg, double min, String what, String where) {
    expect(
      Contrast.ratio(fg, bg),
      greaterThanOrEqualTo(min - 0.005),
      reason:
          '$what in $where: ${fg.toARGB32().toRadixString(16)} on '
          '${bg.toARGB32().toRadixString(16)}',
    );
  }

  // Default is authored to the blueprint (docs/design/monivo-blueprint.html,
  // :root): its neutrals are pinned exactly, and its hairline, input fill,
  // track and drag handle are as quiet as the blueprint draws them, so the
  // derived palettes' visibility floors don't apply to it.
  group('Default palette is the blueprint', () {
    String hex(Color c) =>
        '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    for (final (brightness, want) in [
      (
        Brightness.light,
        {
          'page': '#F3F3F6',
          'card': '#FFFFFF',
          'inset': '#ECECF1',
          'track': '#E3E3E9',
          'hairline': '#E2E2E8',
          'ink': '#17191F',
          'ink2': '#4E505A',
          'ink3': '#666874',
          'okFill': '#D7EDE1',
          'cautionFill': '#F5E6D3',
          'errorFill': '#EED3D4',
          'infoFill': '#D8E6F1',
        },
      ),
      (
        Brightness.dark,
        {
          'page': '#101013',
          'card': '#1B1B20',
          'inset': '#222228',
          'track': '#2E2E35',
          'hairline': '#2B2B32',
          'ink': '#F2F2F6',
          'ink2': '#C4C5CE',
          'ink3': '#9EA0AB',
          'okFill': '#173A2A',
          'cautionFill': '#45331C',
          'errorFill': '#6E2B2E',
          'infoFill': '#1F3546',
        },
      ),
    ]) {
      test(brightness.name, () {
        final theme = brightness == Brightness.light
            ? AppTheme.buildLightTheme(ColorPalette.defaultPalette)
            : AppTheme.buildDarkTheme(ColorPalette.defaultPalette);
        final c = theme.colorScheme;
        final t = theme.extension<AppColorTokens>()!;
        expect({
          'page': hex(theme.scaffoldBackgroundColor),
          'card': hex(theme.cardTheme.color!),
          'inset': hex(c.surfaceContainer),
          'track': hex(c.surfaceContainerHighest),
          'hairline': hex(c.outlineVariant),
          'ink': hex(c.onSurface),
          'ink2': hex(c.onSurfaceVariant),
          'ink3': hex(t.textTertiary),
          'okFill': hex(t.successContainer),
          'cautionFill': hex(t.warningContainer),
          'errorFill': hex(t.errorContainer),
          'infoFill': hex(t.infoContainer),
        }, want);
      });
    }
  });

  for (final palette in ColorPalette.values) {
    final blueprint = palette == ColorPalette.defaultPalette;
    for (final brightness in Brightness.values) {
      final where = '$palette/${brightness.name}';
      final theme = brightness == Brightness.light
          ? AppTheme.buildLightTheme(palette)
          : AppTheme.buildDarkTheme(palette);
      final c = theme.colorScheme;
      final tokens = theme.extension<AppColorTokens>()!;
      final bg = theme.scaffoldBackgroundColor;
      final card = theme.cardTheme.color!;
      final sheet = theme.bottomSheetTheme.backgroundColor!;
      final dialog = theme.dialogTheme.backgroundColor!;
      final inputFill = theme.inputDecorationTheme.fillColor!;
      final textSurfaces = <String, Color>{
        'surface': c.surface,
        'background': bg,
        'card': card,
        'sheet': sheet,
        'dialog': dialog,
        'surfaceContainer': c.surfaceContainer,
        'surfaceContainerHigh': c.surfaceContainerHigh,
        'input fill': inputFill,
      };

      group('$where text', () {
        test('primary and supporting text meet AA on every surface', () {
          for (final s in textSurfaces.entries) {
            expectRatio(c.onSurface, s.value, 4.5, 'onSurface/${s.key}', where);
            expectRatio(
              c.onSurfaceVariant,
              s.value,
              4.5,
              'onSurfaceVariant/${s.key}',
              where,
            );
          }
          expectRatio(tokens.textTertiary, c.surface, 4.5, 'tertiary', where);
          expectRatio(tokens.textTertiary, card, 4.5, 'tertiary/card', where);
          final hint = theme.inputDecorationTheme.hintStyle!.color!;
          expectRatio(hint, inputFill, 4.5, 'hint/input fill', where);
        });

        test('text-bearing accents meet AA on every surface', () {
          final accents = <String, Color>{
            'primary': c.primary,
            'error': c.error,
            'success': tokens.success,
            'warning': tokens.warning,
            'info': tokens.info,
            'income': tokens.income,
            'expense': tokens.expense,
          };
          for (final a in accents.entries) {
            for (final s in textSurfaces.entries) {
              expectRatio(a.value, s.value, 4.5, '${a.key}/${s.key}', where);
            }
          }
        });

        test('decorative accents are visible on the surface', () {
          expectRatio(c.secondary, c.surface, 3.0, 'secondary', where);
          expectRatio(c.tertiary, c.surface, 3.0, 'tertiary', where);
        });
      });

      group('$where fills', () {
        test('"on" colours meet AA on their fill', () {
          expectRatio(c.onPrimary, c.primary, 4.5, 'onPrimary', where);
          expectRatio(c.onSecondary, c.secondary, 4.5, 'onSecondary', where);
          expectRatio(c.onTertiary, c.tertiary, 4.5, 'onTertiary', where);
          expectRatio(c.onError, c.error, 4.5, 'onError', where);
          expectRatio(
            c.onPrimaryContainer,
            c.primaryContainer,
            4.5,
            'onPrimaryContainer',
            where,
          );
          expectRatio(
            c.onSecondaryContainer,
            c.secondaryContainer,
            4.5,
            'onSecondaryContainer',
            where,
          );
          expectRatio(
            c.onTertiaryContainer,
            c.tertiaryContainer,
            4.5,
            'onTertiaryContainer',
            where,
          );
          expectRatio(
            c.onErrorContainer,
            c.errorContainer,
            4.5,
            'onErrorContainer',
            where,
          );
          expectRatio(
            c.onInverseSurface,
            c.inverseSurface,
            4.5,
            'onInverseSurface',
            where,
          );
          expectRatio(
            c.inversePrimary,
            c.inverseSurface,
            4.5,
            'inversePrimary (snackbar action)',
            where,
          );
        });

        test('every status tone is legible on its own container', () {
          for (final tone in AppTone.values) {
            final t = tokens.tone(tone);
            expectRatio(
              t.onContainer,
              t.container,
              4.5,
              'on${tone.name}Container',
              where,
            );
          }
        });

        test('disabled buttons stay understandable', () {
          final style = theme.filledButtonTheme.style!;
          const disabled = {WidgetState.disabled};
          final fill = over(style.backgroundColor!.resolve(disabled)!, card);
          final label = over(style.foregroundColor!.resolve(disabled)!, fill);
          expectRatio(label, fill, 2.5, 'disabled label', where);
        });
      });

      group('$where surfaces and outlines', () {
        test('outlines and hairlines are visible', () {
          expectRatio(c.outline, c.surface, 3.0, 'outline', where);
          if (blueprint) return;
          expectRatio(c.outlineVariant, c.surface, 1.5, 'hairline', where);
          expectRatio(c.outlineVariant, card, 1.5, 'hairline/card', where);
          expectRatio(
            theme.bottomSheetTheme.dragHandleColor!,
            sheet,
            3.0,
            'drag handle',
            where,
          );
        });

        // Reports draws its bars flat on the page: the lead in primary,
        // the rest (and a zero day's tick) in onSurfaceVariant (UX-070,
        // WCAG 1.4.11). The outline is not enough on the light page.
        test('chart bars meet the 3:1 non-text floor on the page', () {
          for (final s in {'background': bg, 'surface': c.surface}.entries) {
            expectRatio(c.primary, s.value, 3.0, 'lead bar/${s.key}', where);
            expectRatio(
              c.onSurfaceVariant,
              s.value,
              3.0,
              'other bars/${s.key}',
              where,
            );
          }
        });

        test('the surface hierarchy is visible', () {
          expectRatio(card, bg, 1.05, 'card/background', where);
          if (blueprint) return;
          expectRatio(inputFill, card, 1.1, 'input fill/card', where);
          expectRatio(
            theme.progressIndicatorTheme.linearTrackColor!,
            card,
            1.3,
            'progress track/card',
            where,
          );
        });
      });

      group('$where navigation bar', () {
        final nav = theme.navigationBarTheme;
        final navBg = nav.backgroundColor!;
        final indicator = nav.indicatorColor!;
        const selected = {WidgetState.selected};
        const unselected = <WidgetState>{};

        test('indicator, icons and labels are legible', () {
          expectRatio(
            indicator,
            navBg,
            brightness == Brightness.dark ? 1.8 : 1.4,
            'indicator/bar',
            where,
          );
          expectRatio(
            nav.iconTheme!.resolve(selected)!.color!,
            indicator,
            4.5,
            'selected icon/indicator',
            where,
          );
          expectRatio(
            nav.iconTheme!.resolve(unselected)!.color!,
            navBg,
            4.5,
            'unselected icon/bar',
            where,
          );
          expectRatio(
            nav.labelTextStyle!.resolve(selected)!.color!,
            navBg,
            4.5,
            'selected label/bar',
            where,
          );
          expectRatio(
            nav.labelTextStyle!.resolve(unselected)!.color!,
            navBg,
            4.5,
            'unselected label/bar',
            where,
          );
        });
      });
    }
  }
}
