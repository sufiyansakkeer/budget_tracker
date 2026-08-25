import 'package:flutter/material.dart';

import '../di/injection.dart' as di;
import '../../features/settings/domain/entities/settings_failure.dart';
import '../../features/settings/domain/usecases/load_settings_usecase.dart';
import 'notification_bloc.dart';
import 'notification_event.dart';

/// Handles notification initialization and scheduling on app startup.
class NotificationInitializer {
  final NotificationBloc _notificationBloc;
  final LoadSettingsUseCase _loadSettingsUseCase;

  NotificationInitializer({
    NotificationBloc? notificationBloc,
    LoadSettingsUseCase? loadSettingsUseCase,
  }) : _notificationBloc = notificationBloc ?? di.getIt<NotificationBloc>(),
       _loadSettingsUseCase =
           loadSettingsUseCase ?? di.getIt<LoadSettingsUseCase>();

  /// Initialize notifications and schedule based on current settings.
  Future<void> initialize() async {
    await _notificationBloc.initializeOnStartup();
  }

  /// Reschedule notifications (call after settings change).
  Future<void> reschedule() async {
    try {
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        _notificationBloc.add(NotificationSchedule(data));
      }
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    }
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    _notificationBloc.add(const NotificationCancel());
  }
}
