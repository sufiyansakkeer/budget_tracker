import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../budget/domain/repository/budget_repository.dart';
import '../entities/app_settings.dart';
import '../entities/notification_settings.dart';

/// Manages local notification scheduling for reminders, summaries and alerts.
///
/// Uses [flutter_local_notifications] with timezone-aware daily scheduling.
/// Notification bodies are budget-aware: they reference the currently active
/// budget so users always know which budget a notification belongs to.
class NotificationService {
  static const int _morningReminderId = 1001;
  static const int _eveningSummaryId = 1002;
  static const int _overspendingAlertId = 1003;
  static const int _noExpenseReminderId = 1004;

  final FlutterLocalNotificationsPlugin _plugin;
  final BudgetRepository? _budgetRepository;
  bool _initialized = false;

  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    BudgetRepository? budgetRepository,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _budgetRepository = budgetRepository;

  /// Initializes the plugin and requests notification permissions.
  Future<bool> initialize() async {
    if (_initialized) return true;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    final ok = await _plugin.initialize(settings);
    _initialized = ok ?? true;
    return _initialized;
  }

  /// Requests notification permission (relevant on iOS).
  Future<bool> requestPermission() async {
    await initialize();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return (await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )) ??
          false;
    }
    return true; // Android 13+ handled by plugin; default granted.
  }

  /// Schedules all daily notifications based on [settings].
  ///
  /// Notification bodies are budget-aware: they reference the currently active
  /// budget so the user always knows which budget a reminder belongs to.
  Future<void> scheduleAll(AppSettings settings) async {
    await initialize();
    await cancelAll();
    if (!settings.notifications.notificationsEnabled) return;

    final budgetName = await _activeBudgetName();
    final notifications = settings.notifications;

    if (notifications.morningReminderEnabled) {
      await _scheduleDaily(
        id: _morningReminderId,
        title: "Today's Safe Spending",
        body: budgetName == null
            ? 'Check your daily budget allowance.'
            : '$budgetName — Check your daily budget allowance.',
        time: notifications.morningReminderTime,
        settings: settings,
      );
    }

    if (notifications.eveningSummaryEnabled) {
      await _scheduleDaily(
        id: _eveningSummaryId,
        title: 'Evening Summary',
        body: budgetName == null
            ? 'Review how much you spent today.'
            : '$budgetName — Review how much you spent today.',
        time: notifications.eveningSummaryTime,
        settings: settings,
      );
    }

    if (notifications.overspendingAlertsEnabled) {
      await _scheduleDaily(
        id: _overspendingAlertId,
        title: 'Budget Alert',
        body: budgetName == null
            ? "You exceeded today's allowance."
            : "$budgetName — You exceeded today's allowance.",
        time: notifications.eveningSummaryTime,
        settings: settings,
      );
    }

    if (notifications.noExpenseReminderEnabled &&
        notifications.dailyRemindersEnabled) {
      await _scheduleDaily(
        id: _noExpenseReminderId,
        title: 'Daily Reminder',
        body: budgetName == null
            ? "You haven't recorded any expenses today."
            : "$budgetName — You haven't recorded any expenses today.",
        time: notifications.morningReminderTime,
        settings: settings,
      );
    }
  }

  /// Resolves the name of the currently active budget for notification bodies.
  Future<String?> _activeBudgetName() async {
    try {
      final repo = _budgetRepository;
      if (repo == null) return null;
      final budget = await repo.getActiveBudget();
      return budget?.name;
    } catch (_) {
      return null;
    }
  }

  /// Schedules a repeating daily notification at [time] respecting quiet hours.
  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required NotificationTime time,
    required AppSettings settings,
  }) async {
    final notifications = settings.notifications;

    // Skip scheduling if within quiet hours.
    if (notifications.quietHoursEnabled &&
        _isWithinQuietHours(time, notifications)) {
      return;
    }

    final scheduledDate = _nextInstanceOfHourMinute(time.hour, time.minute);

    const androidDetails = AndroidNotificationDetails(
      'budget_reminders',
      'Budget Reminders',
      channelDescription: 'Daily budget reminders and summaries',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Cancels a specific notification by id.
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  bool _isWithinQuietHours(
    NotificationTime time,
    NotificationSettings notifications,
  ) {
    final start =
        notifications.quietHoursStart.hour * 60 +
        notifications.quietHoursStart.minute;
    final end =
        notifications.quietHoursEnd.hour * 60 +
        notifications.quietHoursEnd.minute;
    final current = time.hour * 60 + time.minute;

    if (start <= end) {
      return current >= start && current <= end;
    }
    // Overnight range (e.g. 22:00 -> 07:00).
    return current >= start || current <= end;
  }

  tz.TZDateTime _nextInstanceOfHourMinute(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Whether the plugin is ready for scheduling.
  bool get isInitialized => _initialized;
}
