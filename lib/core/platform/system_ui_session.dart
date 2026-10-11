import 'package:flutter/foundation.dart';

/// Marks the time the app hands the screen to a system UI it opened itself:
/// a file picker, the save dialog, the share sheet, the camera.
///
/// The app lock re-locks when the app leaves the foreground. Those system
/// screens take the foreground too, so without this every backup, export,
/// import or receipt photo ended on the lock screen, and its result message
/// was hidden behind it. While a session runs the lock gate does not lock;
/// a session longer than [maxDuration] locks on return as usual, so leaving
/// a picker open is never a way around the lock.
abstract final class SystemUiSession {
  static int _depth = 0;
  static DateTime? _startedAt;

  /// The clock sessions are timed with; tests replace it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// The longest a session holds the lock off.
  static const Duration maxDuration = Duration(minutes: 5);

  /// The time on the session clock, for timing a skipped lock.
  static DateTime now() => clock();

  /// Whether an app-opened system UI is showing, within [maxDuration].
  static bool get isActive {
    final started = _startedAt;
    if (_depth == 0 || started == null) return false;
    return clock().difference(started) <= maxDuration;
  }

  /// Runs [action], which opens a system UI, as a session.
  static Future<T> run<T>(Future<T> Function() action) async {
    if (_depth++ == 0) _startedAt = clock();
    try {
      return await action();
    } finally {
      if (--_depth == 0) _startedAt = null;
    }
  }

  /// Ends every session (tests).
  @visibleForTesting
  static void reset() {
    _depth = 0;
    _startedAt = null;
  }
}
