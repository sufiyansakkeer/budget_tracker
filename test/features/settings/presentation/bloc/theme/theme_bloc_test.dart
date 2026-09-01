import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:monivo/features/settings/domain/repository/theme_repository.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_event.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_state.dart';
import 'package:bloc_test/bloc_test.dart';
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
  group('ThemeBloc', () {
    blocTest<ThemeBloc, ThemeState>(
      'emits system by default when nothing is persisted',
      build: () => ThemeBloc(
        themeRepository: _FakeThemeRepository()..stored = AppThemeMode.system,
      ),
      expect: () => [const ThemeState(mode: AppThemeMode.system)],
    );

    blocTest<ThemeBloc, ThemeState>(
      'loads persisted dark theme on start',
      build: () => ThemeBloc(
        themeRepository: _FakeThemeRepository()..stored = AppThemeMode.dark,
      ),
      expect: () => [const ThemeState(mode: AppThemeMode.dark)],
    );

    blocTest<ThemeBloc, ThemeState>(
      'transitions light -> dark',
      build: () => ThemeBloc(
        themeRepository: _FakeThemeRepository()..stored = AppThemeMode.light,
      ),
      seed: () => const ThemeState(mode: AppThemeMode.light),
      act: (bloc) => bloc.add(const ThemeChanged(AppThemeMode.dark)),
      expect: () => [const ThemeState(mode: AppThemeMode.dark)],
    );

    blocTest<ThemeBloc, ThemeState>(
      'transitions dark -> light',
      build: () => ThemeBloc(
        themeRepository: _FakeThemeRepository()..stored = AppThemeMode.dark,
      ),
      seed: () => const ThemeState(mode: AppThemeMode.dark),
      act: (bloc) => bloc.add(const ThemeChanged(AppThemeMode.light)),
      expect: () => [const ThemeState(mode: AppThemeMode.light)],
    );

    test('persists the selected theme', () async {
      final repo = _FakeThemeRepository()..stored = AppThemeMode.system;
      final bloc = ThemeBloc(themeRepository: repo);
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ThemeChanged(AppThemeMode.dark));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.mode, AppThemeMode.dark);
      expect(repo.stored, AppThemeMode.dark);

      await bloc.close();
      expect(repo.stored, AppThemeMode.dark);
    });
  });
}
