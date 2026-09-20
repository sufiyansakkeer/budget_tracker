import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

/// Shared scaffold for every onboarding step.
///
/// Header (optional back button, title, subtitle) → scrollable content →
/// pinned footer. The content scrolls, so the keyboard never causes an
/// overflow, and the primary button stays reachable.
class OnboardingStepLayout extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget child;
  final Widget footer;

  /// When false the [child] fills the remaining height itself (for lists).
  final bool scrollable;

  const OnboardingStepLayout({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    required this.child,
    required this.footer,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: IconButton(
                onPressed: onBack,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          )
        else
          const SizedBox(height: AppSpacing.md),
        Expanded(
          child: scrollable
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [header, child],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      Expanded(child: child),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: footer,
        ),
      ],
    );
  }
}

/// Primary onboarding action. Uses [ElevatedButton], which the theme styles
/// identically to a filled button.
class OnboardingContinueButton extends StatelessWidget {
  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool isLoading;

  const OnboardingContinueButton({
    super.key,
    this.buttonKey,
    this.label = 'Continue',
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: double.infinity,
        minHeight: AppSizes.touchTarget + AppSpacing.xs,
      ),
      child: ElevatedButton(
        key: buttonKey,
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(icon, size: AppSizes.iconMd),
                ],
              ),
      ),
    );
  }
}
