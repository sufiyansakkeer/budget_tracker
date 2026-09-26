import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import '../theme/contrast.dart';
import 'pressable.dart';

/// A consistent surface container used across the app.
///
/// Shares the theme's card radius, color and hairline border so every screen
/// feels like one application. When [onTap] is set the card gets a ripple and
/// a subtle press-scale response. Colour and border changes (for example a
/// budget becoming the active one) animate rather than snap.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;

  /// When false the hairline border is omitted (use on tinted surfaces).
  final bool showBorder;

  /// Overrides the hairline border colour (e.g. to highlight the card).
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = EdgeInsets.zero,
    this.color,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.showBorder = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? AppSpacing.borderRadiusLg;
    final interactive = onTap != null || onLongPress != null;

    final content = Padding(padding: padding, child: child);

    Widget card = AnimatedContainer(
      duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
      curve: AppMotion.standardCurve,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? theme.cardTheme.color,
        borderRadius: radius,
        border: showBorder
            ? Border.all(color: borderColor ?? theme.colorScheme.outlineVariant)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: interactive
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: radius,
                child: content,
              ),
            )
          : content,
    );

    if (interactive) card = Pressable(child: card);
    return card;
  }
}

/// A compact row with an icon tile, title and subtitle — used for summary
/// tiles and settings-style rows inside a card.
class AppCardTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppCardTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            IconTile(icon: icon, color: iconColor),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A rounded, tinted square holding a single icon. The standard leading
/// element for list rows and cards.
///
/// Pass [animate] true where the colour or icon reflects a status that can
/// change while on screen (bill paid, spending over limit); the tile then
/// cross-fades between states instead of snapping.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  /// Renders as a circle instead of a rounded square.
  final bool circular;

  /// Animate colour and icon changes.
  final bool animate;

  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = AppSizes.avatarMd,
    this.iconSize,
    this.circular = false,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = iconSize ?? size * 0.5;
    if (!animate) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circular ? null : AppSpacing.borderRadiusSmd,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: resolvedIconSize, color: color),
      );
    }

    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: duration,
      curve: AppMotion.standardCurve,
      builder: (context, animated, _) {
        final c = animated ?? color;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular ? null : AppSpacing.borderRadiusSmd,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
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
              size: resolvedIconSize,
              color: c,
            ),
          ),
        );
      },
    );
  }
}

/// Utility card for colored status accents (used by insights/alerts).
class StatusCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  final String? title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.color,
    required this.icon,
    required this.message,
    this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The card's tint is [color] at 8%; the title has to stay legible on it.
    final tint = Color.alphaBlend(
      color.withValues(alpha: 0.08),
      theme.colorScheme.surface,
    );
    final titleColor = Contrast.ensureContrast(color, tint);
    final card = Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: AppSpacing.borderRadiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: icon,
                color: color,
                size: AppSizes.avatarSm,
                circular: true,
                animate: true,
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return card;
    return Pressable(child: card);
  }
}
