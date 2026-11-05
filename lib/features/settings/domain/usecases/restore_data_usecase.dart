import '../entities/settings_failure.dart';
import '../services/backup_service.dart';

/// Restores the database from a backup file.
class RestoreDataUseCase {
  final BackupService backupService;

  RestoreDataUseCase({required this.backupService});

  Future<SettingsResult<String>> call(String path) => _guard(() async {
    final metadata = await backupService.restore(path);
    return 'Restored backup from ${metadata.createdAt.toIso8601String()} '
        '(schema v${metadata.schemaVersion}).';
  });

  /// What the backup at [path] holds, without restoring it, so the
  /// confirmation can describe the file. Fails as [call] would, before
  /// anything is asked.
  Future<SettingsResult<BackupSummary>> preview(String path) =>
      _guard(() => backupService.readSummary(path));

  Future<SettingsResult<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return SettingsSuccess(await run());
    } on WrongFileKindException catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.wrongFileKind,
          message: e.message,
        ),
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
