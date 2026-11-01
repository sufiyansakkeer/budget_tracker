import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/platform/system_ui_session.dart';

/// Handles local receipt image storage (capture or gallery).
/// Stores only the local file path; never uploads anywhere.
class ReceiptStorageService {
  ReceiptStorageService._();

  static final ReceiptStorageService instance = ReceiptStorageService._();

  final ImagePicker _picker = ImagePicker();

  /// Directory where receipts are stored locally.
  Future<Directory> _receiptsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'receipts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Captures a receipt from the camera.
  Future<String?> captureReceipt() async {
    // The camera takes the foreground; keep the app lock from re-locking.
    final file = await SystemUiSession.run(
      () => _picker.pickImage(source: ImageSource.camera, imageQuality: 70),
    );
    if (file == null) return null;
    return _copyToLocal(file);
  }

  /// Picks a receipt from the gallery.
  Future<String?> pickReceiptFromGallery() async {
    final file = await SystemUiSession.run(
      () => _picker.pickImage(source: ImageSource.gallery, imageQuality: 70),
    );
    if (file == null) return null;
    return _copyToLocal(file);
  }

  /// Copies the picked image into the app's receipts directory.
  Future<String> _copyToLocal(XFile file) async {
    final dir = await _receiptsDir();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
    final destPath = p.join(dir.path, fileName);
    final sourceFile = File(file.path);
    if (await sourceFile.exists()) {
      await sourceFile.copy(destPath);
      return destPath;
    }
    // Fallback: if the source cannot be copied, use the original path.
    return file.path;
  }

  /// Deletes the stored receipts no expense points to: the expense was
  /// deleted, the receipt replaced or removed, or the form discarded. Run
  /// at startup, before a form can hold a picked receipt not yet saved, and
  /// after any Undo has expired. Returns how many files were deleted.
  Future<int> deleteUnreferenced(AppDatabase database) async =>
      deleteUnreferencedIn(await _receiptsDir(), database);

  /// [deleteUnreferenced] for the receipts in [dir]. Files are matched by
  /// name: iOS moves the app's folder on updates, so a stored path can name
  /// an old folder while the file sits in the new one.
  @visibleForTesting
  static Future<int> deleteUnreferencedIn(
    Directory dir,
    AppDatabase database,
  ) async {
    final path = database.expenses.receiptImagePath;
    final rows =
        await (database.selectOnly(database.expenses)
              ..addColumns([path])
              ..where(path.isNotNull()))
            .get();
    final referenced = {for (final row in rows) p.basename(row.read(path)!)};

    var deleted = 0;
    await for (final entry in dir.list()) {
      if (entry is! File || referenced.contains(p.basename(entry.path))) {
        continue;
      }
      try {
        await entry.delete();
        deleted++;
      } on FileSystemException catch (e) {
        debugPrint('[error] Deleting an unused receipt: $e');
      }
    }
    return deleted;
  }

  /// Gracefully checks whether a receipt file exists.
  bool receiptExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}
