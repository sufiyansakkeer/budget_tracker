import 'package:flutter/material.dart';

import '../../../../core/widgets/confirmation_dialog.dart';

/// Confirmation dialog shown before budget resets, imports and restores.
///
/// Thin wrapper over the shared [ConfirmationDialog] so every confirmation in
/// the app looks the same.
class ResetConfirmationDialog {
  ResetConfirmationDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    IconData icon = Icons.warning_amber_rounded,
    bool isDestructive = true,
  }) {
    return ConfirmationDialog.show(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      icon: icon,
      isDestructive: isDestructive,
    );
  }
}
