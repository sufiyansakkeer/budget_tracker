import 'package:flutter/foundation.dart';

/// The words people see when something fails.
///
/// A failure written for people (a validation message, a duplicate name) is
/// shown as it is. Anything else can carry exception text, file paths or
/// ids, so it is replaced with [fallback], a sentence that says what didn't
/// happen and what to do, and the original goes to the log.
String userFacingError(
  String message, {
  required bool forPeople,
  required String fallback,
}) {
  if (forPeople) return message;
  debugPrint('[error] $message');
  return fallback;
}
