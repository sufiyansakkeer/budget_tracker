import 'package:rive/rive.dart';

/// Loads each `.riv` file once per process and shares it between icons.
///
/// A [RiveFile] is immutable; every icon creates its own artboard instance
/// from it, so four tabs cost one asset read and one parse.
class RiveFileCache {
  RiveFileCache._();

  static final Map<String, Future<RiveFile>> _files = {};

  static Future<RiveFile> load(String asset) {
    return _files.putIfAbsent(asset, () => RiveFile.asset(asset));
  }

  /// Drops cached files. Only tests need this.
  static void clear() => _files.clear();
}
