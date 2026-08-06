import '../entities/app_settings.dart';
import '../entities/settings_failure.dart';
import '../services/notification_service.dart';

/// Schedules (or cancels) local notifications based on [settings].
class ScheduleNotificationsUseCase {
  final NotificationService notificationService;

  ScheduleNotificationsUseCase({required this.notificationService});

  Future<SettingsResult<void>> call(AppSettings settings) async {
    try {
      await notificationService.scheduleAll(settings);
      return const SettingsSuccess(null);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.notificationPermissionDenied,
          message: 'Failed to schedule notifications: ${e.toString()}',
        ),
      );
    }
  }
}
