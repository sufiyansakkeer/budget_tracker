import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

/// How far a surface sits from the page.
enum SurfaceLevel {
  /// The one surface that leads a screen (the Home hero): the card tone,
  /// the large radius and a soft shadow, with no border.
  raised,

  /// A quiet grouping on the page (a summary row, a notice): one step
  /// darker (light) or lighter (dark) than the page, no shadow, no border.
  sunken,
}

/// A surface without the hairline border every `AppCard` draws, so a
/// screen can set one element apart and leave the rest on the page.
///
/// With [onTap] the surface is one button for screen readers, labelled
/// [semanticLabel] when given.
class AppSurface extends StatelessWidget {
  final Widget child;
  final SurfaceLevel level;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const AppSurface({
    super.key,
    required this.child,
    this.level = SurfaceLevel.raised,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raised = level == SurfaceLevel.raised;
    final radius = raised
        ? AppSpacing.borderRadiusLg
        : AppSpacing.borderRadiusMd;
    final color = raised
        ? theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow
        : theme.colorScheme.surfaceContainer;
    // A soft, wide shadow lifts the raised surface in light mode. In dark
    // mode the same shadow disappears into the page and the lighter card
    // tone carries the lift, so no brightness check is needed.
    final shadow = raised
        ? [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ]
        : null;

    final content = Padding(padding: padding, child: child);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: shadow,
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: content,
              ),
            ),
    );
    if (onTap == null) return surface;
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: semanticLabel != null,
      child: surface,
    );
  }
}
