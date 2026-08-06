import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/notification_settings.dart';

/// A settings row for a labelled notification time with a time-picker action.
class NotificationTimeTile extends StatelessWidget {
  final String title;
  final NotificationTime time;
  final ValueChanged<NotificationTime> onChanged;

  const NotificationTimeTile({
    super.key,
    required this.title,
    required this.time,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
    );
    if (picked != null) {
      onChanged(NotificationTime(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(time.displayLabel),
      trailing: const Icon(Icons.schedule),
      onTap: () => _pick(context),
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
    );
  }
}
