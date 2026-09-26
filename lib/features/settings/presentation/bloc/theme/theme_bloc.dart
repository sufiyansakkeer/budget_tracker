import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repository/theme_repository.dart';
import 'theme_event.dart';
import 'theme_state.dart';

/// Global application theme BLoC.
///
/// [ThemeBloc] is the single source of truth for the app's theme. It loads the
/// persisted preference on startup and exposes it via [ThemeState]. When the
/// user changes the theme or palette, the state is emitted immediately (so the
/// UI updates without a restart) and the preference is then persisted locally.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final ThemeRepository _themeRepository;

  final Completer<void> _ready = Completer<void>();

  /// Completes once the persisted theme has been read (or failed to read),
  /// so the first frame can already use the user's palette and mode
  /// instead of flashing the defaults and animating to them.
  Future<void> get ready => _ready.future;

  ThemeBloc({required ThemeRepository themeRepository})
    : _themeRepository = themeRepository,
      super(const ThemeState()) {
    on<ThemeLoadRequested>((event, emit) async {
      try {
        final results = await Future.wait([
          _themeRepository.getTheme(),
          _themeRepository.getPalette(),
        ]);
        final mode = results[0] as dynamic; // AppThemeMode
        final palette = results[1] as dynamic; // ColorPalette
        if (!isClosed) emit(ThemeState(mode: mode, palette: palette));
      } catch (_) {
        // Keep the default theme mode on error.
      } finally {
        if (!_ready.isCompleted) _ready.complete();
      }
    });
    on<ThemeChanged>((event, emit) async {
      emit(state.copyWith(mode: event.mode));
      await _themeRepository.saveTheme(event.mode);
    });
    on<ColorPaletteChanged>((event, emit) async {
      emit(state.copyWith(palette: event.palette));
      await _themeRepository.savePalette(event.palette);
    });
    add(const ThemeLoadRequested());
  }
}
