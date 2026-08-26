import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/currency/currency_formatter.dart';
import '../../../../features/budget/domain/repository/budget_repository.dart';
import '../../../../features/budget/domain/services/budget_calculation_service.dart';
import '../entities/app_settings.dart';
import '../../../dashboard/domain/usecases/get_spending_targets_usecase.dart';
import '../usecases/get_today_safe_spending_usecase.dart';

/// Manages local notification scheduling for reminders, summaries and alerts.
///
/// Uses [flutter_local_notifications] with timezone-aware daily scheduling.
/// Notification bodies are budget-aware and use the centralized currency formatter.
class NotificationService {
  static const MethodChannel _recoveryChannel = MethodChannel(
    'monivo/notifications',
  );
  static const int morningReminderId = 1001;
  static const int eveningSummaryId = 1002;
  static const int overspendingAlertId = 1003;
  static const int noExpenseReminderId = 1004;
  static const int testNotificationId = 1999;

  static const String channelId = 'budget_reminders';
  static const String channelName = 'Budget Reminders';
  static const String channelDescription =
      'Daily budget reminders and summaries';

  final FlutterLocalNotificationsPlugin _plugin;
  final BudgetRepository budgetRepository;
  final BudgetCalculationService calculationService;
  final GetSpendingTargetsUseCase spendingTargetsUseCase;
  bool _initialized = false;
  bool _timeZonesConfigured = false;

  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    required this.budgetRepository,
    required this.calculationService,
    required this.spendingTargetsUseCase,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Initializes the plugin, timezone database, and Android notification channel.
  Future<bool> initialize() async {
    if (_initialized) return true;

    debugPrint('[Notifications] Initializing');

    await _configureLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    debugPrint('[Notifications] Timezone initialized');
    final ok = await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    if (ok != true) {
      return false;
    }

    await _createAndroidNotificationChannel();
    _initialized = true;
    debugPrint('[Notifications] Plugin initialized');
    return true;
  }

  /// Requests native notification permission on Android 13+ and iOS.
  Future<bool> requestPermission() async {
    try {
      await initialize();

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return true;
    } catch (e, st) {
      debugPrint('[NotificationService] Error requesting permission: $e\n$st');
      return false;
    }
  }

  /// Returns whether notifications are enabled at the OS level.
  Future<bool> areNotificationsEnabled() async {
    await initialize();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final settings = await ios.checkPermissions();
      return settings?.isEnabled ?? false;
    }

    return true;
  }

  /// Schedules all daily notifications based on [settings].
  ///
  /// The morning notification body is dynamically calculated from the
  /// current budget data using [GetTodaySafeSpendingUseCase].
  Future<void> scheduleAll(AppSettings settings) async {
    await initialize();
    await cancelAllPending();

    final notifSettings = settings.notifications;
    if (!notifSettings.notificationsEnabled) return;

    if (notifSettings.morningReminderEnabled) {
      final safeSpending = await _getTodaySafeSpending(
        fallbackCurrency: settings.currencyCode,
      );

      final body = safeSpending != null
          ? 'You can safely spend ${CurrencyFormatter.format(
              safeSpending.amount,
              code: safeSpending.currency,
              decimalDigits: 0,
            )} today.'
          : 'Check your budget and plan your spending for today.';

      debugPrint('[Notification] Morning notification body: $body');

      await _scheduleDailyNotification(
        id: morningReminderId,
        title: "Today's Spending Limit",
        body: body,
        hour: notifSettings.morningReminderTime.hour,
        minute: notifSettings.morningReminderTime.minute,
      );
    }

    if (notifSettings.eveningSummaryEnabled) {
      await _scheduleDailyNotification(
        id: eveningSummaryId,
        title: 'Evening Summary 🌙',
        body: 'Review your spending for today.',
        hour: notifSettings.eveningSummaryTime.hour,
        minute: notifSettings.eveningSummaryTime.minute,
      );
    }
  }

  /// Schedules a one-off test notification one minute from now.
  ///
  /// Intended for development verification of permission, channel, and delivery.
  /// Uses the same dynamic calculation as the morning notification.
  Future<void> scheduleTestNotification({AppSettings? settings}) async {
    await initialize();

    final currencyCode = settings?.currencyCode ?? 'INR';

    final safeSpending = await _getTodaySafeSpending(
      fallbackCurrency: currencyCode,
    );

    final formattedAmount = safeSpending != null
        ? CurrencyFormatter.format(
            safeSpending.amount,
            code: safeSpending.currency,
            decimalDigits: 0,
          )
        : CurrencyFormatter.format(
            0,
            code: currencyCode,
            decimalDigits: 0,
          );

    debugPrint('[Notification] Test notification amount: $formattedAmount');

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
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

    final scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(minutes: 1));

    await _plugin.zonedSchedule(
      testNotificationId,
      "Today's Spending Limit",
      'You can safely spend $formattedAmount today.',
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAll() async {
    await _cancelWithRecovery(() => _plugin.cancelAll());
  }

  /// Cancels scheduled notifications without touching already displayed ones.
  Future<void> cancelAllPending() async {
    await _cancelWithRecovery(() => _plugin.cancelAllPendingNotifications());
  }

  /// Cancels a specific notification by id.
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Whether the plugin is ready for scheduling.
  bool get isInitialized => _initialized;

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Fetches today's safe spending using the same business logic as the
  /// Dashboard's "Today's Safe Spending" section.
  Future<SafeSpendingResult?> _getTodaySafeSpending({
    String fallbackCurrency = 'INR',
  }) async {
    try {
      final useCase = GetTodaySafeSpendingUseCase(
        spendingTargetsUseCase: spendingTargetsUseCase,
      );
      return await useCase(fallbackCurrency: fallbackCurrency);
    } catch (e, st) {
      debugPrint('[Notification] Error calculating safe spending: $e\n$st');
      return null;
    }
  }

  Future<void> _configureLocalTimeZone() async {
    if (_timeZonesConfigured) return;

    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      debugPrint(
        '[NotificationService] Resolved timezone: ${timezoneInfo.identifier}',
      );
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e, st) {
      debugPrint(
        '[NotificationService] Failed to resolve local timezone: $e\n$st',
      );
      debugPrint('[NotificationService] Falling back to UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _timeZonesConfigured = true;
  }

  Future<void> _cancelWithRecovery(Future<void> Function() cancel) async {
    try {
      await cancel();
    } catch (e, st) {
      if (!_isScheduledNotificationDeserializationError(e)) rethrow;

      debugPrint(
        '[Notifications] Recovery triggered for persisted schedules: $e\n$st',
      );
      await _recoveryChannel.invokeMethod<void>(
        'clearScheduledNotificationsStore',
      );
      debugPrint('[Notifications] Notification recovery completed');
      await cancel();
    }
  }

  bool _isScheduledNotificationDeserializationError(Object error) {
    return error.toString().contains('Missing type parameter');
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    switch (payload) {
      case 'daily_spending_limit':
      case 'evening_summary':
        debugPrint('[Notifications] Received notification: $payload');
      default:
        debugPrint('[Notifications] Ignoring unknown notification payload');
    }
  }

  Future<void> _createAndroidNotificationChannel() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );
  }
}
