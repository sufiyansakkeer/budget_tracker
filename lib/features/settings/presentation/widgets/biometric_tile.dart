import 'package:flutter/material.dart';

/// A settings tile for enabling/disabling the biometric lock.
///
/// This widget is a pure view driven by the BLoC. It does NOT perform
/// authentication or availability checks itself — it only reflects the state
/// provided from the outside and dispatches a change request upward.
///
/// The switch value is controlled by [enabled] (the source of truth), the tile
/// is disabled while [isBusy] (e.g. during authentication), and a friendly
/// status [message] is shown as the subtitle when provided.
class BiometricTile extends StatelessWidget {
  final bool enabled;
  final bool isBusy;
  final String? message;
  final ValueChanged<bool> onChanged;

  const BiometricTile({
    super.key,
    required this.enabled,
    this.isBusy = false,
    this.message,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = isBusy
        ? 'Authenticating...'
        : (message ?? 'Use fingerprint or Face ID to unlock the app');

    return SwitchListTile(
      title: const Text('Biometric Lock'),
      subtitle: Text(subtitle),
      secondary: isBusy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.fingerprint),
      value: enabled,
      onChanged: isBusy ? null : onChanged,
      dense: true,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}
