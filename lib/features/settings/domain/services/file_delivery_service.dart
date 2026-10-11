import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/platform/system_ui_session.dart';

/// Where a file the app made goes next.
enum FileDestination {
  /// A folder the user picks in the system's save dialog (Downloads, Files,
  /// a cloud drive). The file stays there, so Restore can pick it later.
  device,

  /// The share sheet: Drive, email, a chat, "Save to Files".
  share,
}

/// What happened to a delivered file, as far as the platform can tell.
enum FileDeliveryOutcome {
  /// Written to a location the user chose.
  saved,

  /// Handed to an app the user chose in the share sheet.
  shared,

  /// The share sheet closed, but the platform did not say whether an app
  /// was chosen.
  handedOff,

  /// The user closed the save dialog or the share sheet without choosing.
  cancelled,
}

/// Puts a file the app made somewhere the user can reach it.
///
/// A file in the app's own storage is invisible to the user, to the system
/// file picker and to the next install, so a backup only counts once it has
/// been delivered. The outcome is reported as it is: a cancelled save is
/// never reported as a saved one.
class FileDeliveryService {
  const FileDeliveryService();

  Future<FileDeliveryOutcome> deliver({
    required File file,
    required String fileName,
    required String mimeType,
    required String extension,
    required FileDestination destination,
    String? shareText,
  }) => SystemUiSession.run(() async {
    switch (destination) {
      case FileDestination.device:
        final path = await FilePicker.platform.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [extension],
          bytes: await file.readAsBytes(),
        );
        if (path == null) return FileDeliveryOutcome.cancelled;
        // Android and iOS write the bytes themselves; desktop dialogs only
        // return the chosen path.
        if (!Platform.isAndroid && !Platform.isIOS) await file.copy(path);
        return FileDeliveryOutcome.saved;
      case FileDestination.share:
        final result = await Share.shareXFiles(
          [XFile(file.path, mimeType: mimeType, name: fileName)],
          text: shareText,
          fileNameOverrides: [fileName],
        );
        return switch (result.status) {
          ShareResultStatus.success => FileDeliveryOutcome.shared,
          ShareResultStatus.dismissed => FileDeliveryOutcome.cancelled,
          ShareResultStatus.unavailable => FileDeliveryOutcome.handedOff,
        };
    }
  });
}
