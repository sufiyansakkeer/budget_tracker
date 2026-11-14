import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// JSON work on files that can hold years of records, run on a short-lived
/// isolate so a large backup, export or restore doesn't freeze the screen.
///
/// Only plain data crosses: maps, lists, strings and numbers in, a string
/// or decoded JSON out. The bytes are the ones the UI isolate wrote before
/// (UTF-8, two-space indent).
abstract final class JsonOffMain {
  /// Writes [value] to [file] as indented JSON.
  static Future<void> writeIndented(File file, Object? value) async {
    final text = await Isolate.run(
      () => const JsonEncoder.withIndent('  ').convert(value),
    );
    await file.writeAsString(text);
  }

  /// The file at [path] read as UTF-8 and decoded. Throws
  /// [FormatException] when it isn't JSON, and the file system's error when
  /// it can't be read.
  static Future<Object?> decodeFile(String path) async =>
      decode(await File(path).readAsString());

  /// [raw] decoded. Throws [FormatException] when it isn't JSON.
  static Future<Object?> decode(String raw) =>
      Isolate.run(() => jsonDecode(raw));
}
