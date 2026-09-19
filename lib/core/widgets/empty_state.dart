import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

/// A reusable empty state with an icon, title, message and optional action.
///
/// Use the default constructor for full-screen empties and [EmptyState.compact]
/// for an inline section placeholder (e.g. "no recent expenses" inside the
/// dashboard).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Optional secondary, low-emphasis action.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  final bool _compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  }) : _compact = false;

  /// A smaller inline variant for use inside a scrolling page.
  const EmptyState.compact({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  }) : _compact = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: _compact ? AppSizes.avatarLg : AppSizes.avatarXl,
          height: _compact ? AppSizes.avatarLg : AppSizes.avatarXl,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: _compact ? AppSizes.iconLg : AppSizes.iconHero,
            color: colorScheme.primary,
          ),
        ),
        SizedBox(height: _compact ? AppSpacing.smd : AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            title,
            style: _compact
                ? theme.textTheme.titleMedium
                : theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: _compact ? AppSpacing.md : AppSpacing.lg),
          _compact
              ? FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.add_rounded),
                  label: Text(actionLabel!),
                )
              : FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.add_rounded),
                  label: Text(actionLabel!),
                ),
        ],
        if (secondaryActionLabel != null && onSecondaryAction != null) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: onSecondaryAction,
            child: Text(secondaryActionLabel!),
          ),
        ],
      ],
    );

    if (_compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        child: Center(child: body),
      );
    }

    return Center(
      child: SingleChildScrollView(padding: AppSpacing.paddingXl, child: body),
    );
  }
}

/// Friendly error state with a retry action.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final String title;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try Again',
    this.title = 'Something went wrong',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppSizes.avatarXl,
              height: AppSizes.avatarXl,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.error_outline_rounded,
                size: AppSizes.iconHero,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
