import '../entities/settings_failure.dart';
import '../entities/theme_mode_entity.dart';
import '../repository/settings_repository.dart';

/// Updates the application theme mode.
class UpdateThemeUseCase {
  final SettingsRepository repository;

  UpdateThemeUseCase({required this.repository});

  Future<SettingsResult<void>> call(AppThemeMode mode) async {
    try {
      await repository.setThemeMode(mode);
      return const SettingsSuccess(null);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.saveFailure,
          message: 'Failed to save theme preference: ${e.toString()}',
        ),
      );
    }
  }
}
