import 'package:equatable/equatable.dart';

/// Time-of-day stored as hour/minute (24h) for notification scheduling.
class NotificationTime extends Equatable {
  final int hour;
  final int minute;

  const NotificationTime({required this.hour, required this.minute});

  /// Parses a "HH:mm" string.
  static NotificationTime fromString(String? value) {
    if (value == null || value.isEmpty)
      return const NotificationTime(hour: 9, minute: 0);
    final parts = value.split(':');
    if (parts.length != 2) return const NotificationTime(hour: 9, minute: 0);
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    return NotificationTime(
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }

  String toSettingString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get displayLabel {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [hour, minute];
}

/// Defines all user-configurable notification preferences.
class NotificationSettings extends Equatable {
  final bool notificationsEnabled;
  final bool morningReminderEnabled;
  final NotificationTime morningReminderTime;
  final bool eveningSummaryEnabled;
  final NotificationTime eveningSummaryTime;
  final bool overspendingAlertsEnabled;
  final bool dailyRemindersEnabled;
  final bool noExpenseReminderEnabled;
  final bool quietHoursEnabled;
  final NotificationTime quietHoursStart;
  final NotificationTime quietHoursEnd;

  const NotificationSettings({
    this.notificationsEnabled = true,
    this.morningReminderEnabled = true,
    this.morningReminderTime = const NotificationTime(hour: 9, minute: 0),
    this.eveningSummaryEnabled = true,
    this.eveningSummaryTime = const NotificationTime(hour: 20, minute: 0),
    this.overspendingAlertsEnabled = true,
    this.dailyRemindersEnabled = true,
    this.noExpenseReminderEnabled = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = const NotificationTime(hour: 22, minute: 0),
    this.quietHoursEnd = const NotificationTime(hour: 7, minute: 0),
  });

  NotificationSettings copyWith({
    bool? notificationsEnabled,
    bool? morningReminderEnabled,
    NotificationTime? morningReminderTime,
    bool? eveningSummaryEnabled,
    NotificationTime? eveningSummaryTime,
    bool? overspendingAlertsEnabled,
    bool? dailyRemindersEnabled,
    bool? noExpenseReminderEnabled,
    bool? quietHoursEnabled,
    NotificationTime? quietHoursStart,
    NotificationTime? quietHoursEnd,
  }) {
    return NotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      morningReminderEnabled:
          morningReminderEnabled ?? this.morningReminderEnabled,
      morningReminderTime: morningReminderTime ?? this.morningReminderTime,
      eveningSummaryEnabled:
          eveningSummaryEnabled ?? this.eveningSummaryEnabled,
      eveningSummaryTime: eveningSummaryTime ?? this.eveningSummaryTime,
      overspendingAlertsEnabled:
          overspendingAlertsEnabled ?? this.overspendingAlertsEnabled,
      dailyRemindersEnabled:
          dailyRemindersEnabled ?? this.dailyRemindersEnabled,
      noExpenseReminderEnabled:
          noExpenseReminderEnabled ?? this.noExpenseReminderEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  @override
  List<Object?> get props => [
    notificationsEnabled,
    morningReminderEnabled,
    morningReminderTime,
    eveningSummaryEnabled,
    eveningSummaryTime,
    overspendingAlertsEnabled,
    dailyRemindersEnabled,
    noExpenseReminderEnabled,
    quietHoursEnabled,
    quietHoursStart,
    quietHoursEnd,
  ];
}
