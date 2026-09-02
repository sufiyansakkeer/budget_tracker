import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/color_palettes.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:monivo/features/settings/domain/repository/theme_repository.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_event.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeThemeRepository implements ThemeRepository {
  AppThemeMode stored = AppThemeMode.system;
  ColorPalette storedPalette = ColorPalette.defaultPalette;

  @override
  Future<AppThemeMode> getTheme() async => stored;

  @override
  Future<void> saveTheme(AppThemeMode mode) async => stored = mode;

  @override
  Future<ColorPalette> getPalette() async => storedPalette;

  @override
  Future<void> savePalette(ColorPalette palette) async =>
      storedPalette = palette;
}

/// Displays the current Theme primary color so we can verify propagation.
class _ThemeProbe extends StatelessWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context) {
    final schemePrimary = Theme.of(context).colorScheme.primary.toARGB32();
    final appColorsPrimary = context.appColors.primary.toARGB32();
    return Text('primary:$schemePrimary:appColors:$appColorsPrimary');
  }
}

void main() {
  testWidgets(
    'Palette switch propagates through BlocBuilder → MaterialApp → Theme',
    (tester) async {
      final repo = _FakeThemeRepository()
        ..stored = AppThemeMode.light
        ..storedPalette = ColorPalette.defaultPalette;
      final bloc = ThemeBloc(themeRepository: repo);

      await tester.pumpWidget(
        BlocProvider<ThemeBloc>(
          create: (_) => bloc,
          child: BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              return MaterialApp(
                key: ValueKey('theme_${state.palette}_${state.mode}'),
                theme: AppTheme.buildLightTheme(state.palette),
                darkTheme: AppTheme.buildDarkTheme(state.palette),
                themeMode: state.mode.toThemeMode(),
                home: const Scaffold(body: _ThemeProbe()),
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Verify initial Default palette.
      expect(bloc.state.palette, ColorPalette.defaultPalette);
      final defaultPrimary = getPaletteColors(
        ColorPalette.defaultPalette,
      ).lightScheme.primary.toARGB32();
      expect(
        find.text('primary:$defaultPrimary:appColors:$defaultPrimary'),
        findsOneWidget,
        reason: 'Initial palette should be Default',
      );

      // ── Switch to Ocean ──
      bloc.add(const ColorPaletteChanged(ColorPalette.ocean));
      await tester.pump();
      await tester.pump();

      final oceanPrimary = getPaletteColors(
        ColorPalette.ocean,
      ).lightScheme.primary.toARGB32();
      final allTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();

      expect(
        allTexts.any((t) => t.contains('$oceanPrimary')),
        isTrue,
        reason:
            'After switching to Ocean, theme primary should be $oceanPrimary but got $allTexts',
      );

      // ── Switch to Forest ──
      bloc.add(const ColorPaletteChanged(ColorPalette.forest));
      await tester.pump();
      await tester.pump();

      final forestPrimary = getPaletteColors(
        ColorPalette.forest,
      ).lightScheme.primary.toARGB32();
      final texts2 = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();

      expect(
        texts2.any((t) => t.contains('$forestPrimary')),
        isTrue,
        reason:
            'After switching to Forest, theme primary should be $forestPrimary but got $texts2',
      );

      await bloc.close();
    },
  );

  testWidgets('Dark mode + palette switch uses correct dark scheme', (
    tester,
  ) async {
    final repo = _FakeThemeRepository()
      ..stored = AppThemeMode.dark
      ..storedPalette = ColorPalette.defaultPalette;
    final bloc = ThemeBloc(themeRepository: repo);

    await tester.pumpWidget(
      BlocProvider<ThemeBloc>(
        create: (_) => bloc,
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return MaterialApp(
              key: ValueKey('theme_${state.palette}_${state.mode}'),
              theme: AppTheme.buildLightTheme(state.palette),
              darkTheme: AppTheme.buildDarkTheme(state.palette),
              themeMode: state.mode.toThemeMode(),
              home: const Scaffold(body: _ThemeProbe()),
            );
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    final defaultDarkPrimary = getPaletteColors(
      ColorPalette.defaultPalette,
    ).darkScheme.primary.toARGB32();
    expect(
      find.text('primary:$defaultDarkPrimary:appColors:$defaultDarkPrimary'),
      findsOneWidget,
    );

    // Switch to Ocean in dark mode.
    bloc.add(const ColorPaletteChanged(ColorPalette.ocean));
    await tester.pump();
    await tester.pump();

    final oceanDarkPrimary = getPaletteColors(
      ColorPalette.ocean,
    ).darkScheme.primary.toARGB32();
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();

    expect(
      texts.any((t) => t.contains('$oceanDarkPrimary')),
      isTrue,
      reason: 'Dark mode + Ocean should use Ocean dark scheme primary',
    );

    await bloc.close();
  });

  test('All 6 palettes produce distinct primary colors', () {
    final results = <ColorPalette, int>{};
    for (final palette in ColorPalette.values) {
      results[palette] = AppTheme.buildLightTheme(
        palette,
      ).colorScheme.primary.toARGB32();
    }
    expect(
      results.values.toSet().length,
      ColorPalette.values.length,
      reason: 'Each palette should have a unique primary color',
    );
  });
}
