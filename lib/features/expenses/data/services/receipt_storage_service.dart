import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (file == null) return null;
    return _copyToLocal(file);
  }

  /// Picks a receipt from the gallery.
  Future<String?> pickReceiptFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
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

  /// Removes a stored receipt file. Returns true if the file was deleted.
  Future<bool> removeReceipt(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
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
