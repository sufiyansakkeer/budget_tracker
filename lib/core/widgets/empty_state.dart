import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import 'fade_slide_in.dart';

/// A reusable empty state with an icon, title, message and optional action.
///
/// Use the default constructor for full-screen empties and [EmptyState.compact]
/// for an inline section placeholder (e.g. "no recent expenses" inside the
/// dashboard). The icon settles in with a gentle scale and the copy follows
/// with a short stagger — once, when the state appears.
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
        StateIconReveal(
          child: Container(
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
        ),
        SizedBox(height: _compact ? AppSpacing.smd : AppSpacing.lg),
        FadeSlideIn(
          index: 1,
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: _compact
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        FadeSlideIn(
          index: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: _compact ? AppSpacing.md : AppSpacing.lg),
          FadeSlideIn(
            index: 3,
            child: _compact
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
          ),
        ],
        if (secondaryActionLabel != null && onSecondaryAction != null) ...[
          const SizedBox(height: AppSpacing.xs),
          FadeSlideIn(
            index: 4,
            child: TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
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
///
/// Content fades in rather than flashing on, and the message is never hidden
/// behind the animation — only opacity and a few pixels of travel change.
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
            StateIconReveal(
              child: Container(
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
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              index: 1,
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FadeSlideIn(
              index: 2,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              index: 3,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scales an illustration icon from slightly small to full size while fading
/// it in. Runs once on mount; honours reduced motion.
class StateIconReveal extends StatelessWidget {
  final Widget child;

  const StateIconReveal({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.emphasized,
      curve: AppMotion.emphasizedDecelerate,
      child: child,
      builder: (context, t, child) {
        if (t >= 1) return child!;
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
        );
      },
    );
  }
}
