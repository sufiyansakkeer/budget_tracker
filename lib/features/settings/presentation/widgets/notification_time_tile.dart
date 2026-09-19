import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/notification_settings.dart';

/// A settings row for a labelled notification time with a time-picker action.
class NotificationTimeTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final NotificationTime time;
  final ValueChanged<NotificationTime> onChanged;
  final IconData icon;

  /// When false the row is shown muted and cannot be tapped (e.g. when
  /// notifications are turned off).
  final bool enabled;

  const NotificationTimeTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.time,
    required this.onChanged,
    this.icon = Icons.schedule_rounded,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      helpText: title,
    );
    if (picked != null) {
      onChanged(NotificationTime(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      leading: IconTile(
        icon: icon,
        color: enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        size: AppSizes.avatarSm,
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: AppSpacing.borderRadiusSm,
        ),
        child: Text(
          time.displayLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      onTap: enabled ? () => _pick(context) : null,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
    );
  }
}
