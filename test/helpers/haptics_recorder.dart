import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every haptic the app asks for, as the platform sees it
/// ("HapticFeedbackType.lightImpact" for `AppHaptics.confirm`).
///
/// It answers every other platform-channel call with null, as the test
/// binding's default does.
List<String> recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      calls.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

/// What `AppHaptics.confirm` sends.
const confirmHaptic = 'HapticFeedbackType.lightImpact';
