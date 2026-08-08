import 'package:flutter/material.dart';
import '../di/injection.dart' as di;
import '../../features/settings/domain/entities/settings_failure.dart';
import '../../features/settings/domain/services/notification_service.dart';
import '../../features/settings/domain/usecases/load_settings_usecase.dart';

/// Handles notification initialization and scheduling on app startup.
class NotificationInitializer {
  final NotificationService _notificationService;
  final LoadSettingsUseCase _loadSettingsUseCase;

  NotificationInitializer({
    NotificationService? notificationService,
    LoadSettingsUseCase? loadSettingsUseCase,
  })  : _notificationService = notificationService ?? di.getIt<NotificationService>(),
        _loadSettingsUseCase = loadSettingsUseCase ?? di.getIt<LoadSettingsUseCase>();

  /// Initialize notifications and schedule based on current settings.
  Future<void> initialize() async {
    try {
      // Initialize the notification plugin
      final initialized = await _notificationService.initialize();
      if (!initialized) {
        debugPrint('Failed to initialize notification service');
        return;
      }

      // Request permissions
      final hasPermission = await _notificationService.requestPermission();
      if (!hasPermission) {
        debugPrint('Notification permission denied');
        return;
      }

      // Load settings and schedule notifications
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        final settings = data;
        await _notificationService.scheduleAll(settings);
        debugPrint('Notifications scheduled successfully');
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Reschedule notifications (call after settings change).
  Future<void> reschedule() async {
    try {
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        final settings = data;
        await _notificationService.scheduleAll(settings);
      }
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    }
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    try {
      await _notificationService.cancelAll();
    } catch (e) {
      debugPrint('Error canceling notifications: $e');
    }
  }
}