import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/app_theme.dart';
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

  for (final palette in ColorPalette.values) {
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

        test('the surface hierarchy is visible', () {
          expectRatio(card, bg, 1.05, 'card/background', where);
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
