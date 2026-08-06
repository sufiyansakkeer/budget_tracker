import 'package:flutter/material.dart';

/// A confirmation dialog shown before destructive budget actions.
class ResetConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final IconData icon;
  final bool isDestructive;

  const ResetConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.icon = Icons.warning_amber_rounded,
    this.isDestructive = true,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    IconData icon = Icons.warning_amber_rounded,
    bool isDestructive = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ResetConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        icon: icon,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(
        icon,
        size: 48,
        color: isDestructive
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
