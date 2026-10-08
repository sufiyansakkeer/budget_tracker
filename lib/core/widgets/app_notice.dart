import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../theme/app_tone.dart';

/// Something the user should know or act on, as one quiet row: a tone
/// icon, a title, a sentence and at most one action.
///
/// Notices sit on a sunken surface rather than a tinted card, so several of
/// them never turn a screen into a wall of colour. The action goes under the
/// sentence instead of beside it, so at large text sizes the sentence keeps
/// its full width.
class AppNotice extends StatelessWidget {
  final AppTone tone;
  final IconData icon;
  final String title;
  final String message;

  /// Usually a `TextButton`.
  final Widget? action;

  const AppNotice({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.smd,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(
                icon,
                size: AppSizes.iconMd,
                color: context.tone(tone).accent,
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (action == null)
                    const SizedBox(height: AppSpacing.sm)
                  else
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: action,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
