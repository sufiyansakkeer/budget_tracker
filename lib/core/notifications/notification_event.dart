import 'package:equatable/equatable.dart';

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

/// Re-reads settings and re-schedules the daily notifications so their text
/// reflects the latest expenses and budgets. Fired (debounced) after data
/// changes; only acts while notifications are ready.
class NotificationRefreshSchedule extends NotificationEvent {
  const NotificationRefreshSchedule();
}
