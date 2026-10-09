import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_event.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_state.dart';
import 'package:monivo/features/settings/presentation/pages/palette_selection_screen.dart';

import 'settings_test_harness.dart';

void main() {
  Future<StaticThemeBloc> pump(
    WidgetTester tester, {
    ColorPalette selected = ColorPalette.defaultPalette,
    Brightness brightness = Brightness.light,
    double width = 360,
    double textScale = 1,
  }) async {
    final bloc = StaticThemeBloc(ThemeState(palette: selected));
    addTearDown(bloc.close);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(width * 2, 6000 * textScale);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: BlocProvider<ThemeBloc>.value(
              value: bloc,
              child: const PaletteSelectionScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  Finder tile(ColorPalette palette) =>
      find.byKey(Key('palette_${palette.name}'));

  testWidgets('every palette is previewed in light and dark', (tester) async {
    await pump(tester);

    for (final option in paletteOptions) {
      expect(find.text(option.label), findsOneWidget);
      expect(
        find.descendant(
          of: tile(option.palette),
          matching: find.byType(AspectRatio),
        ),
        findsNWidgets(2),
        reason: '${option.label}: one light and one dark preview',
      );
    }
  });

  testWidgets('tapping a palette selects it', (tester) async {
    final bloc = await pump(tester);

    await tester.tap(tile(ColorPalette.forest));
    await tester.pump();

    expect(
      bloc.received,
      contains(
        isA<ColorPaletteChanged>().having(
          (e) => e.palette,
          'palette',
          ColorPalette.forest,
        ),
      ),
    );
  });

  testWidgets('the current palette is marked for sight and screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, selected: ColorPalette.ocean);

    expect(
      find.descendant(
        of: tile(ColorPalette.ocean),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      tester.getSemantics(tile(ColorPalette.ocean)),
      containsSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(tile(ColorPalette.forest)),
      containsSemantics(isSelected: false, isButton: true),
    );
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('meets tap target, label and contrast guidelines '
        '(${brightness.name})', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, brightness: brightness, selected: ColorPalette.ocean);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  testWidgets('fits a small screen at twice the text size, in dark', (
    tester,
  ) async {
    await pump(tester, brightness: Brightness.dark, width: 320, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text(paletteOptions.last.label), findsOneWidget);
  });
}
