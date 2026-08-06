import 'package:flutter/material.dart';

import '../../domain/services/biometric_service.dart';

/// A settings tile for enabling/disabling the biometric lock.
///
/// Checks device support before toggling and shows a clear error when
/// biometrics are unavailable.
class BiometricTile extends StatefulWidget {
  final bool enabled;
  final BiometricService biometricService;
  final ValueChanged<bool> onChanged;

  const BiometricTile({
    super.key,
    required this.enabled,
    required this.biometricService,
    required this.onChanged,
  });

  @override
  State<BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<BiometricTile> {
  bool _checking = false;

  Future<void> _toggle(bool value) async {
    if (value) {
      setState(() => _checking = true);
      final available = await widget.biometricService.canUseBiometrics();
      setState(() => _checking = false);
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Biometrics are not available on this device, or no '
                'fingerprint/Face ID is registered.',
              ),
            ),
          );
        }
        return;
      }
      // Require a successful authentication before enabling.
      final ok = await widget.biometricService.authenticate(
        reason: 'Confirm to enable biometric lock',
      );
      if (!ok) return;
    }
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Biometric Lock'),
      subtitle: const Text('Use fingerprint or Face ID to unlock the app'),
      secondary: const Icon(Icons.fingerprint),
      value: widget.enabled,
      onChanged: _checking ? null : _toggle,
      dense: true,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}
