import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import '../theme/app_colors_extension.dart';
import '../theme/app_tone.dart';
import '../theme/contrast.dart';

/// A small pill-shaped status indicator combining an icon + label.
///
/// Used instead of relying on color alone so status is accessible via text
/// and icon too. Colour, icon and label changes animate in place, so a bill
/// flipping from "Due today" to "Paid" reads as one smooth state change.
///
/// Prefer [StatusChip.tone]: it draws with the tone's contrast-checked
/// container and text colours, so a chip looks the same on the page, on a
/// card and in a sheet. The [color] form tints an arbitrary accent.
class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  final AppTone? tone;
  final IconData icon;
  final bool filled;

  /// Lets the label wrap onto more lines when the chip is narrower than it
  /// (large text on a small screen) instead of overflowing. Only for a chip
  /// given a bounded width (e.g. a [Wrap] child, or inside [Flexible]); a
  /// plain [Row] child is unbounded and must keep the default.
  final bool wrapLabel;

  const StatusChip({
    super.key,
    required this.label,
    required Color this.color,
    required this.icon,
    this.filled = false,
    this.wrapLabel = false,
  }) : tone = null;

  /// A chip in an [AppTone]'s container and on-container colours.
  const StatusChip.tone({
    super.key,
    required this.label,
    required AppTone this.tone,
    required this.icon,
    this.wrapLabel = false,
  }) : color = null,
       filled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );
    final Color background;
    final Color foreground;
    if (tone != null) {
      final colors = context.tone(tone!);
      background = colors.container;
      foreground = colors.onContainer;
    } else {
      final accent = color!;
      // The tint behind an unfilled chip is [color] at 12% over the
      // surface, which sits close enough to the surface that the accent
      // itself is often unreadable on it (a warning amber lands near 2:1).
      // Darken/lighten the label only as far as legibility requires; the
      // tint keeps the meaning.
      final tint = Color.alphaBlend(
        accent.withValues(alpha: 0.12),
        theme.colorScheme.surface,
      );
      background = filled ? accent : accent.withValues(alpha: 0.12);
      foreground = filled
          ? theme.colorScheme.onPrimary
          : Contrast.ensureContrast(accent, tint);
    }
    final textStyle =
        theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ) ??
        TextStyle(color: foreground, fontWeight: FontWeight.w700);

    final text = AnimatedDefaultTextStyle(
      duration: duration,
      curve: AppMotion.standardCurve,
      style: textStyle,
      child: Text(label),
    );

    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.standardCurve,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: duration,
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              icon,
              key: ValueKey(icon.codePoint),
              // Grows with the label at large text sizes, up to a normal
              // icon, so a chip never pairs big text with a tiny glyph.
              size: MediaQuery.textScalerOf(
                context,
              ).scale(AppSizes.iconXs).clamp(AppSizes.iconXs, AppSizes.iconLg),
              color: foreground,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (wrapLabel) Flexible(child: text) else text,
        ],
      ),
    );
  }
}

/// Factory helpers for common statuses using the active palette.
class StatusChipStyles {
  StatusChipStyles._();

  static StatusChip healthy(BuildContext context, String label) => StatusChip(
    label: label,
    color: context.appColors.success,
    icon: Icons.check_circle_rounded,
  );

  static StatusChip warning(BuildContext context, String label) => StatusChip(
    label: label,
    color: context.appColors.warning,
    icon: Icons.warning_amber_rounded,
  );

  static StatusChip danger(BuildContext context, String label) => StatusChip(
    label: label,
    color: context.appColors.error,
    icon: Icons.error_rounded,
  );

  static StatusChip info(BuildContext context, String label) => StatusChip(
    label: label,
    color: context.appColors.primary,
    icon: Icons.info_rounded,
  );
}
