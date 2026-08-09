package com.example.budget_tracker

import io.flutter.embedding.android.FlutterFragmentActivity

// IMPORTANT: Must extend FlutterFragmentActivity (not FlutterActivity) so the
// local_auth plugin can attach its BiometricPrompt fragment. The default
// FlutterActivity is a plain Activity and is NOT a FragmentActivity, which
// prevents the native biometric prompt from appearing on Android.
class MainActivity : FlutterFragmentActivity()
