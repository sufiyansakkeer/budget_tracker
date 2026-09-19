import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';

/// Sticky Save action for the expense form.
///
/// Shows a spinner while saving and a brief check mark once saved, so the
/// confirmation is visible without a blocking dialog.
class ExpenseFormActions extends StatelessWidget {
  final bool isSaving;
  final bool isSaved;
  final bool isEditing;
  final VoidCallback onSave;
  final VoidCallback? onCancel;

  const ExpenseFormActions({
    super.key,
    required this.isSaving,
    this.isSaved = false,
    required this.isEditing,
    required this.onSave,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = isSaving || isSaved;

    final Widget icon;
    final String label;
    if (isSaved) {
      icon = const Icon(Icons.check_circle_rounded, key: ValueKey('saved'));
      label = 'Saved';
    } else if (isSaving) {
      icon = SizedBox(
        key: const ValueKey('saving'),
        width: AppSizes.iconMd,
        height: AppSizes.iconMd,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
      label = 'Saving…';
    } else {
      icon = const Icon(Icons.check_rounded, key: ValueKey('idle'));
      label = isEditing ? 'Save changes' : 'Add expense';
    }

    return Row(
      children: [
        if (onCancel != null) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
        ],
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            key: const Key('saveExpenseButton'),
            onPressed: busy ? null : onSave,
            style: isSaved
                ? FilledButton.styleFrom(
                    disabledBackgroundColor: theme.colorScheme.primary,
                    disabledForegroundColor: theme.colorScheme.onPrimary,
                  )
                : null,
            icon: AnimatedSwitcher(
              duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: icon,
            ),
            label: Text(label),
          ),
        ),
      ],
    );
  }
}
