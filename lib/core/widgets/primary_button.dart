import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import 'pressable.dart';

/// The app's one primary action, and every form's and sheet's Save
/// (UX-110). Wraps a [FilledButton]; the icon, when there is one, comes
/// before the label.
///
/// Presses in slightly when tapped. While [isLoading] the label fades out
/// and a spinner takes its place *without changing the button's size*, the
/// button keeps its primary colour so the action still looks intentional,
/// and it ignores taps so a double tap can't fire the action twice. After a
/// save, [isDone] shows a check mark and [doneLabel] the same way, until the
/// screen closes. Only a button with nothing to do ([onPressed] null) greys
/// out. Disabled buttons never run the press animation.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;

  /// Saved: a check mark and [doneLabel], still primary and inert.
  final bool isDone;
  final String doneLabel;

  /// The key of the [FilledButton] itself, for finders that read it.
  final Key? buttonKey;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.isDone = false,
    this.doneLabel = 'Saved',
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final busy = isLoading || isDone;
    final enabled = onPressed != null && !busy;
    final duration = AppMotion.respectReducedMotion(context, AppMotion.fast);
    final shownIcon = isDone ? Icons.check_circle_rounded : icon;

    final button = FilledButton(
      key: buttonKey,
      onPressed: busy ? null : onPressed,
      style: busy
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
                if (shownIcon != null) ...[
                  Icon(shownIcon, size: AppSizes.iconMd),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    isDone ? doneLabel : label,
                    textAlign: TextAlign.center,
                  ),
                ),
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
