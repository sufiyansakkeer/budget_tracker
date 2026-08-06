import '../entities/settings_failure.dart';
import '../services/backup_service.dart';

/// Creates a full local database backup.
class BackupDataUseCase {
  final BackupService backupService;

  BackupDataUseCase({required this.backupService});

  Future<SettingsResult<String>> call() async {
    try {
      final path = await backupService.createBackup();
      return SettingsSuccess(path);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.backupFailure,
          message: 'Failed to create backup: ${e.toString()}',
        ),
      );
    }
  }
}
