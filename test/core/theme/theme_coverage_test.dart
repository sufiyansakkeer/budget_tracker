import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/contrast.dart';
import 'package:monivo/core/widgets/app_card.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';

/// UX-107: the components the theme used to leave on Material defaults
/// (badge, date-range picker, ListTile titles, icon-tile tints) now come
/// from the tokens, for every palette in light and dark.
void main() {
  void expectRatio(Color fg, Color bg, double min, String what) {
    expect(
      Contrast.ratio(fg, bg),
      greaterThanOrEqualTo(min - 0.005),
      reason:
          '$what: ${fg.toARGB32().toRadixString(16)} on '
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

      group(where, () {
        test('badges are the brand colour, not the error red', () {
          final badge = theme.badgeTheme;
          expect(badge.backgroundColor, c.primary);
          expect(badge.backgroundColor, isNot(c.error));
          expectRatio(badge.textColor!, badge.backgroundColor!, 4.5, 'badge');
          expectRatio(
            badge.backgroundColor!,
            theme.scaffoldBackgroundColor,
            3,
            'badge dot on the page',
          );
        });

        test('the date-range picker is themed like the date picker', () {
          final picker = theme.datePickerTheme;
          expect(picker.rangePickerBackgroundColor, picker.backgroundColor);
          expect(picker.rangePickerElevation, 0);
          expect(picker.rangePickerSurfaceTintColor, Colors.transparent);
          expect(
            picker.rangePickerHeaderBackgroundColor,
            picker.headerBackgroundColor,
          );
          expect(
            picker.rangePickerHeaderForegroundColor,
            picker.headerForegroundColor,
          );
          expectRatio(
            picker.rangePickerHeaderForegroundColor!,
            picker.rangePickerHeaderBackgroundColor!,
            4.5,
            'range header',
          );
          final range = picker.rangeSelectionBackgroundColor!;
          expect(range, isNot(c.secondaryContainer));
          // Day numbers inside the range, and today's, stay legible.
          expectRatio(c.onSurface, range, 4.5, 'day in range');
          final today = picker.todayForegroundColor!.resolve({})!;
          expectRatio(today, range, 4.5, 'today in range');
          expectRatio(today, picker.backgroundColor!, 4.5, 'today');
          expect(
            picker.todayForegroundColor!.resolve({WidgetState.selected}),
            c.onPrimary,
          );
        });

        test('ListTile titles use the AppListRow title role', () {
          final title = theme.listTileTheme.titleTextStyle!;
          final row = theme.textTheme.titleSmall!;
          expect(title.fontSize, row.fontSize);
          expect(title.fontWeight, row.fontWeight);
          expect(title.height, row.height);
        });

        test('the tint alpha is the one the status containers use', () {
          final tokens = theme.extension<AppColorTokens>()!;
          final alpha = AppColorTokens.tintAlpha(brightness);
          expect(
            tokens.successContainer,
            Color.alphaBlend(
              tokens.success.withValues(alpha: alpha),
              tokens.surface,
            ),
          );
        });
      });
    }
  }

  for (final brightness in Brightness.values) {
    for (final animate in [false, true]) {
      testWidgets('IconTile takes its tint from the tokens '
          '(${brightness.name}, animate: $animate)', (tester) async {
        final theme = brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme;
        const accent = Color(0xFF1E88E5);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Center(
              child: IconTile(
                icon: Icons.home_rounded,
                color: accent,
                animate: animate,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final box = tester.widget<Container>(
          find.descendant(
            of: find.byType(IconTile),
            matching: find.byType(Container),
          ),
        );
        final fill = (box.decoration! as BoxDecoration).color!;
        expect(fill.a, closeTo(AppColorTokens.tintAlpha(brightness), 0.005));
      });
    }
  }
}
