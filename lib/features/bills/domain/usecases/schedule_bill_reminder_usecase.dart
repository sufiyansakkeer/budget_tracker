import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/currency/currency_formatter.dart';
import '../../../settings/domain/services/notification_service.dart';
import '../entities/bill_entity.dart';
import '../repository/bill_repository.dart';

/// Manages local notification scheduling for bill reminders.
///
/// Uses deterministic notification IDs derived from the bill's ID so
/// notifications can be reliably cancelled and rescheduled.
class BillReminderService {
  static const String channelId = 'bill_reminders';
  static const String channelName = 'Bill Reminders';
  static const String channelDescription =
      'Reminders for upcoming and overdue bills';

  final FlutterLocalNotificationsPlugin _plugin;
  final BillRepository _repository;

  /// The app's one notification tap handler
  /// ([NotificationService.handleNotificationResponse]). The plugin keeps
  /// only the handler of its latest initialize call, so this one must pass
  /// it too or a Pay later reminder tap would stop opening its tab.
  final DidReceiveNotificationResponseCallback _onNotificationResponse;
  bool _initialized = false;
  bool _timeZonesConfigured = false;

  BillReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    required BillRepository repository,
    required DidReceiveNotificationResponseCallback onNotificationResponse,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _repository = repository,
       _onNotificationResponse = onNotificationResponse;

  /// Ensures the notification plugin and timezone are configured.
  Future<void> initialize() async {
    if (_initialized) return;
    await _configureLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channel for Android.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );
    }
    _initialized = true;
  }

  /// Schedules a reminder notification for the given bill.
  /// Does nothing if the reminder is disabled or the reminder time is in the past.
  Future<void> scheduleReminder(BillEntity bill) async {
    await initialize();

    final reminderTime = bill.reminderDateTime;
    if (reminderTime == null) return;

    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(
      tz.local,
      reminderTime.year,
      reminderTime.month,
      reminderTime.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    // Never schedule notifications for past times.
    if (scheduled.isBefore(now)) return;

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      icon: NotificationService.notificationIcon,
      color: NotificationService.notificationColor,
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

    final (title, body) = reminderText(bill);

    try {
      await _plugin.zonedSchedule(
        bill.notificationId,
        title,
        body,
        scheduled,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint(
        '[BillReminder] Scheduled notification ${bill.notificationId} '
        'for ${bill.title} at $scheduled',
      );
    } catch (e) {
      debugPrint(
        '[BillReminder] Failed to schedule notification for ${bill.title}: $e',
      );
    }
  }

  /// The reminder's title and text, for the day it fires: that is
  /// [BillEntity.reminderOffsetDays] before the due date, whenever it was
  /// scheduled. The system draws it, so the amount goes through
  /// [CurrencyFormatter.forSystemText].
  static (String, String) reminderText(BillEntity bill) {
    final amount = CurrencyFormatter.forSystemText(
      CurrencyFormatter.format(bill.amount, code: bill.currency),
    );
    final daysBefore = bill.reminderOffsetDays;
    if (daysBefore <= 0) {
      return (
        'Bill due today',
        'Your ${bill.title} bill of $amount is due today.',
      );
    }
    if (daysBefore == 1) {
      return (
        'Bill due tomorrow',
        '${bill.title} bill of $amount is due tomorrow.',
      );
    }
    return (
      'Upcoming bill',
      '${bill.title} bill of $amount is due in $daysBefore days.',
    );
  }

  /// Cancels a reminder notification for the given bill.
  Future<void> cancelReminder(BillEntity bill) async {
    await initialize();
    try {
      await _plugin.cancel(bill.notificationId);
      debugPrint(
        '[BillReminder] Cancelled notification ${bill.notificationId} '
        'for ${bill.title}',
      );
    } catch (e) {
      debugPrint(
        '[BillReminder] Failed to cancel notification for ${bill.title}: $e',
      );
    }
  }

  /// Reschedules all bill reminders from scratch.
  /// Called on app startup and after settings changes.
  Future<void> rescheduleAll() async {
    await initialize();
    try {
      final bills = await _repository.getBills();
      for (final bill in bills) {
        if (!bill.isPaid && bill.reminderEnabled) {
          await scheduleReminder(bill);
        }
      }
    } catch (e) {
      debugPrint('[BillReminder] Failed to reschedule all: $e');
    }
  }

  Future<void> _configureLocalTimeZone() async {
    if (_timeZonesConfigured) return;
    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('[BillReminder] Failed to resolve timezone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _timeZonesConfigured = true;
  }
}
