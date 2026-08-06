import '../entities/settings_failure.dart';
import '../services/backup_service.dart';

/// Restores the database from a backup file.
class RestoreDataUseCase {
  final BackupService backupService;

  RestoreDataUseCase({required this.backupService});

  Future<SettingsResult<String>> call(String path) async {
    try {
      final metadata = await backupService.restore(path);
      return SettingsSuccess(
        'Restored backup from ${metadata.createdAt.toIso8601String()} '
        '(schema v${metadata.schemaVersion}).',
      );
    } on FormatException catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.invalidData,
          message: e.message,
        ),
      );
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.restoreFailure,
          message: 'Failed to restore backup: ${e.toString()}',
        ),
      );
    }
  }
}
