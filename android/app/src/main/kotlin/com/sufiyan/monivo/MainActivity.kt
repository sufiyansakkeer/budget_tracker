package com.example.monivo

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

// IMPORTANT: Must extend FlutterFragmentActivity (not FlutterActivity) so the
// local_auth plugin can attach its BiometricPrompt fragment. The default
// FlutterActivity is a plain Activity and is NOT a FragmentActivity, which
// prevents the native biometric prompt from appearing on Android.
class MainActivity : FlutterFragmentActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"monivo/notifications",
		).setMethodCallHandler { call, result ->
			if (call.method == "clearScheduledNotificationsStore") {
				getSharedPreferences("scheduled_notifications", MODE_PRIVATE)
					.edit()
					.clear()
					.apply()
				result.success(null)
			} else {
				result.notImplemented()
			}
		}
	}
}
