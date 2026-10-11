import 'dart:io';

import '../entities/settings_failure.dart';
import '../services/backup_service.dart';
import '../services/file_delivery_service.dart';

/// Creates a full backup and delivers it where the user chose: saved to a
/// folder on the device or shared to another app.
///
/// A backup that stays in the app's own storage cannot be restored (the
/// system file picker cannot see it) and goes with an uninstall, so the
/// result is the delivery outcome. Only [FileDeliveryOutcome.saved] or
/// [FileDeliveryOutcome.shared] mean the backup reached the user.
class BackupDataUseCase {
  final BackupService backupService;
  final FileDeliveryService delivery;

  BackupDataUseCase({
    required this.backupService,
    this.delivery = const FileDeliveryService(),
  });

  Future<SettingsResult<FileDeliveryOutcome>> call({
    required FileDestination destination,
  }) async {
    try {
      final path = await backupService.createBackup();
      final file = File(path);
      final outcome = await delivery.deliver(
        file: file,
        fileName: file.uri.pathSegments.last,
        mimeType: 'application/json',
        extension: 'json',
        destination: destination,
        shareText: 'Monivo backup',
      );
      return SettingsSuccess(outcome);
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
