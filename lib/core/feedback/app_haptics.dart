import 'package:flutter/services.dart';

/// The app's haptic vocabulary. Each method has one meaning, so the same
/// feeling always says the same thing.
///
/// Used sparingly: nothing on scroll, list load or keypad digits.
abstract final class AppHaptics {
  /// A choice changed: a tab, a chip, a period, a segment.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Something was committed: an expense saved, a bill paid.
  static Future<void> confirm() => HapticFeedback.lightImpact();

  /// A gesture crossed a point of no return (swipe-to-delete threshold).
  /// At most once per gesture.
  static Future<void> threshold() => HapticFeedback.mediumImpact();
}
