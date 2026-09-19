import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// A settings tile for enabling/disabling the biometric lock.
///
/// This widget is a pure view driven by the BLoC. It does NOT perform
/// authentication or availability checks itself — it only reflects the state
/// provided from the outside and dispatches a change request upward.
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
    final theme = Theme.of(context);
    final subtitle = isBusy
        ? 'Authenticating...'
        : (message ??
              "Unlock the app with your device's fingerprint, face unlock "
                  'or screen lock. Locks again when you leave the app');

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('Biometric Lock', style: theme.textTheme.titleSmall),
      subtitle: Text(subtitle),
      secondary: isBusy
          ? const SizedBox(
              width: AppSizes.avatarSm,
              height: AppSizes.avatarSm,
              child: Center(
                child: SizedBox(
                  width: AppSizes.iconMd,
                  height: AppSizes.iconMd,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : IconTile(
              icon: Icons.fingerprint,
              color: theme.colorScheme.primary,
              size: AppSizes.avatarSm,
            ),
      value: enabled,
      onChanged: isBusy ? null : onChanged,
    );
  }
}
