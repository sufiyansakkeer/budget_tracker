import '../entities/notification_settings.dart';
import '../entities/settings_failure.dart';
import '../repository/settings_repository.dart';

/// PERSISTS notification preferences.
class UpdateNotificationSettingsUseCase {
  final SettingsRepository repository;

  UpdateNotificationSettingsUseCase({required this.repository});

  Future<SettingsResult<void>> call(NotificationSettings settings) async {
    try {
      await repository.setNotificationSettings(settings);
      return const SettingsSuccess(null);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.saveFailure,
          message: 'Failed to save notification settings: ${e.toString()}',
        ),
      );
    }
  }
}
