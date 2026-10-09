import 'package:flutter/material.dart';

import '../../domain/entities/notification_settings.dart';
import 'settings_tile.dart';

/// A settings row for a labelled notification time; tapping opens the time
/// picker. The time is written the way the device writes times (12- or
/// 24-hour), the same as everywhere else in Settings.
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
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: TimeOfDay(hour: time.hour, minute: time.minute).format(context),
      enabled: enabled,
      onTap: enabled ? () => _pick(context) : null,
    );
  }
}
