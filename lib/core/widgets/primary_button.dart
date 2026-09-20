import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import 'pressable.dart';

/// Standard primary action button (wraps [FilledButton]).
///
/// Presses in slightly when tapped. While [isLoading] the label fades out
/// and a spinner takes its place *without changing the button's size*, the
/// button keeps its primary colour so the action still looks intentional,
/// and it is disabled so a double tap can't fire the action twice.
/// Disabled buttons never run the press animation.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onPressed != null && !isLoading;
    final duration = AppMotion.respectReducedMotion(context, AppMotion.fast);

    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: isLoading
          ? FilledButton.styleFrom(
              disabledBackgroundColor: colorScheme.primary,
              disabledForegroundColor: colorScheme.onPrimary,
            )
          : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            opacity: isLoading ? 0 : 1,
            duration: duration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppSizes.iconMd),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(label),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: duration,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: isLoading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: AppSizes.iconMd,
                    height: AppSizes.iconMd,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),
        ],
      ),
    );

    final pressable = Pressable(enabled: enabled, child: button);
    if (isExpanded) {
      return SizedBox(width: double.infinity, child: pressable);
    }
    return pressable;
  }
}
