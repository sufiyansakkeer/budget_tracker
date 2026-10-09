import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

/// One row of a list: optional leading tile, a title with an optional
/// subtitle, and an optional trailing widget (an amount, a switch, a
/// chevron).
///
/// At least 56 dp tall, with the whole row as the touch target. When
/// [onTap] is set the row is one button for screen readers, labelled with
/// [semanticLabel] or, by default, the title and subtitle.
class AppListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;

  /// Replaces [subtitle] when the second line needs styling of its own.
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  /// What a long press does, read by screen readers ("more actions").
  final String? longPressHint;

  /// Colour for the title, e.g. a destructive action.
  final Color? titleColor;

  const AppListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.longPressHint,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactive = onTap != null || onLongPress != null;
    final second =
        subtitleWidget ??
        (subtitle == null
            ? null
            : Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ));

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.listRowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.smd),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: titleColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (second != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    second,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.smd),
              // An amount may take up to ~45% of the row and then scales
              // down, so the title always keeps room at large text sizes.
              // Sized from the screen rather than a LayoutBuilder, so the
              // row still works inside dialogs that measure intrinsics.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                ),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );

    if (!interactive) {
      return semanticLabel == null
          ? MergeSemantics(child: row)
          : Semantics(label: semanticLabel, excludeSemantics: true, child: row);
    }
    return Semantics(
      button: true,
      label: semanticLabel ?? [title, ?subtitle].join(', '),
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null ? null : longPressHint,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppSpacing.borderRadiusSm,
        child: row,
      ),
    );
  }
}

/// Rows separated by hairlines, with no card around them.
///
/// The divider starts after the leading tile ([dividerIndent]) so the rows
/// read as one list. Set [filled] for a grouped list on its own surface
/// (Settings), which adds a fill, padding and the object-card radius.
class AppGroupedList extends StatelessWidget {
  final List<Widget> children;
  final double dividerIndent;
  final bool filled;

  const AppGroupedList({
    super.key,
    required this.children,
    this.dividerIndent = 0,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              indent: dividerIndent,
              color: theme.colorScheme.outlineVariant,
            ),
          children[i],
        ],
      ],
    );
    if (!filled) return column;
    // A Material rather than a decorated box, so row ink shows on the fill
    // and is clipped to its corners.
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: column,
      ),
    );
  }
}
