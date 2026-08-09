import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repository/theme_repository.dart';
import 'theme_event.dart';
import 'theme_state.dart';

/// Global application theme BLoC.
///
/// [ThemeBloc] is the single source of truth for the app's theme. It loads the
/// persisted preference on startup and exposes it via [ThemeState]. When the
/// user changes the theme, the state is emitted immediately (so the UI updates
/// without a restart) and the preference is then persisted locally.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final ThemeRepository _themeRepository;

  ThemeBloc({required ThemeRepository themeRepository})
    : _themeRepository = themeRepository,
      super(const ThemeState()) {
    on<ThemeLoadRequested>((event, emit) async {
      try {
        final mode = await _themeRepository.getTheme();
        if (!isClosed) emit(ThemeState(mode: mode));
      } catch (_) {
        // Keep the default theme mode on error.
      }
    });
    on<ThemeChanged>((event, emit) async {
      // Emit first so the UI updates immediately, then persist in the
      // background so we never block the UI on disk I/O.
      emit(ThemeState(mode: event.mode));
      await _themeRepository.saveTheme(event.mode);
    });
    add(const ThemeLoadRequested());
  }
}
