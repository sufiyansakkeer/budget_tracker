import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// One settings row: a leading icon tile, a title, optional supporting
/// text, an optional current [value] and a trailing widget (a chevron for
/// rows that open a screen or a sheet).
///
/// Every row in Settings has this anatomy. A destructive row (Restore)
/// takes the error colour for its icon and title.
class SettingsTile extends StatelessWidget {
  final IconData? icon;

  /// Replaces the icon tile, at the same size (the palette swatch).
  final Widget? leading;
  final String title;
  final String? subtitle;

  /// The current choice, muted, before [trailing]: "₹ INR", "8:00 AM".
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Tints the icon and the title with the error colour.
  final bool destructive;

  /// When false the row is muted and cannot be tapped.
  final bool enabled;

  const SettingsTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.enabled = true,
  }) : assert(icon != null || leading != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = !enabled
        ? scheme.onSurfaceVariant
        : destructive
        ? scheme.error
        : scheme.primary;
    final value = this.value;
    final trailing = value == null
        ? this.trailing
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A long value gives way to the title, never the other way.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.32,
                ),
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              if (this.trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                this.trailing!,
              ],
            ],
          );
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      leading:
          leading ??
          IconTile(icon: icon!, color: accent, size: AppSizes.avatarSm),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: destructive && enabled ? scheme.error : null,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: AppSpacing.sm,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
    );
  }
}
