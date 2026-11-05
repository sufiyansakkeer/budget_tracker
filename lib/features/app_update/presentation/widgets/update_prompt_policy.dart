import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the answer to the launch-time update dialog, so it does not
/// interrupt every cold start: "Skip this version" until a newer release,
/// "Later" for [laterFor].
abstract final class UpdatePromptPolicy {
  static const String skippedVersionKey = 'update_prompt_skipped_version';
  static const String laterUntilKey = 'update_prompt_later_until';

  /// How long "Later" keeps the dialog away.
  static const Duration laterFor = Duration(hours: 24);

  /// The clock "Later" is timed with; tests replace it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Whether the launch dialog may offer [version].
  static Future<bool> allows(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(skippedVersionKey) == version) return false;
      final until = prefs.getInt(laterUntilKey);
      return until == null || clock().millisecondsSinceEpoch >= until;
    } catch (e) {
      debugPrint('[error] Reading the update prompt choice: $e');
      return true;
    }
  }

  /// Never offers [version] at launch again; a newer release still shows.
  static Future<void> skip(String version) =>
      _write((prefs) => prefs.setString(skippedVersionKey, version));

  /// Keeps the launch dialog away for [laterFor].
  static Future<void> later() => _write(
    (prefs) => prefs.setInt(
      laterUntilKey,
      clock().add(laterFor).millisecondsSinceEpoch,
    ),
  );

  static Future<void> _write(
    Future<bool> Function(SharedPreferences prefs) write,
  ) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (e) {
      // The dialog comes back at the next launch; nothing else is lost.
      debugPrint('[error] Saving the update prompt choice: $e');
    }
  }
}
