import 'package:monivo/core/theme/app_theme.dart';
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
  Future<void> saveTheme(AppThemeMode mode) async {
    stored = mode;
  }

  @override
  Future<ColorPalette> getPalette() async => storedPalette;

  @override
  Future<void> savePalette(ColorPalette palette) async {
    storedPalette = palette;
  }
}

void main() {
  testWidgets('MaterialApp themeMode follows ThemeBloc state', (tester) async {
    final bloc = ThemeBloc(
      themeRepository: _FakeThemeRepository()..stored = AppThemeMode.light,
    );

    await tester.pumpWidget(
      BlocProvider<ThemeBloc>(
        create: (_) => bloc,
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return MaterialApp(
              theme: AppTheme.buildLightTheme(state.palette),
              darkTheme: AppTheme.buildDarkTheme(state.palette),
              themeMode: state.mode.toThemeMode(),
              home: const Scaffold(body: Text('home')),
            );
          },
        ),
      ),
    );

    // Let the initial ThemeLoadRequested event resolve.
    await tester.pump();
    await tester.pump();

    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));

    // Initial persisted theme is light.
    expect(bloc.state.mode, AppThemeMode.light);
    expect(app().themeMode, ThemeMode.light);

    // Emit dark via the bloc.
    bloc.add(const ThemeChanged(AppThemeMode.dark));
    await tester.pump();
    await tester.pump();
    expect(bloc.state.mode, AppThemeMode.dark);
    expect(app().themeMode, ThemeMode.dark);

    // Emit light again.
    bloc.add(const ThemeChanged(AppThemeMode.light));
    await tester.pump();
    await tester.pump();
    expect(bloc.state.mode, AppThemeMode.light);
    expect(app().themeMode, ThemeMode.light);
  });
}
