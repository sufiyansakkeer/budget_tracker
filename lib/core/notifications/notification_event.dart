import 'package:equatable/equatable.dart';

import '../../features/settings/domain/entities/app_settings.dart';

/// Events for the notification lifecycle BLoC.
sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// Initializes the plugin, requests permission once, and schedules reminders.
class NotificationInitialize extends NotificationEvent {
  const NotificationInitialize();
}

/// Requests native notification permission without rescheduling.
class NotificationRequestPermission extends NotificationEvent {
  const NotificationRequestPermission();
}

/// Reschedules notifications from persisted [settings].
class NotificationSchedule extends NotificationEvent {
  final AppSettings settings;

  const NotificationSchedule(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Cancels all scheduled notifications.
class NotificationCancel extends NotificationEvent {
  const NotificationCancel();
}
