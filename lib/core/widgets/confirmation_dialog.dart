import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../theme/app_colors_extension.dart';

/// A consistent confirmation dialog.
class ConfirmationDialog {
  ConfirmationDialog._();

  /// Shows a confirmation dialog; returns true if confirmed.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData icon = Icons.warning_amber_rounded,
    bool isDestructive = false,
  }) async {
    final appColors = context.appColors;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dc = dialogContext;
        return AlertDialog(
          icon: Icon(
            icon,
            color: isDestructive
                ? appColors.error
                : Theme.of(dc).colorScheme.primary,
            size: 32,
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dc).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              style: isDestructive
                  ? FilledButton.styleFrom(backgroundColor: appColors.error)
                  : null,
              onPressed: () => Navigator.of(dc).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
