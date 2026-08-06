import '../entities/app_settings.dart';
import '../entities/settings_failure.dart';
import '../repository/settings_repository.dart';

/// Loads the current application settings.
class LoadSettingsUseCase {
  final SettingsRepository repository;

  LoadSettingsUseCase({required this.repository});

  Future<SettingsResult<AppSettings>> call() async {
    try {
      final settings = await repository.loadSettings();
      return SettingsSuccess(settings);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.loadFailure,
          message: 'Failed to load settings: ${e.toString()}',
        ),
      );
    }
  }
}
