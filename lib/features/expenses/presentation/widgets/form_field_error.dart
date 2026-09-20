import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

/// Inline validation message for custom (non-TextField) form controls, styled
/// like the theme's input error text and announced to screen readers.
class FormFieldError extends StatelessWidget {
  final String message;

  const FormFieldError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: AppSizes.iconSm,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
