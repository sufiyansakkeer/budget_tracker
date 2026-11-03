import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/currency/currency_formatter.dart';
import '../../../../features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import '../entities/app_settings.dart';
import '../../../dashboard/domain/entities/budget_daily_limit_entity.dart';
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

  /// How many mornings ahead the Today's Safe Spending reminder is
  /// scheduled. Each one is a separate notification carrying the figure for
  /// its own day; a repeating notification would repeat one day's figure
  /// every morning. Every expense, budget or bill change (and every app
  /// start) reschedules them, so they always reflect what has been recorded.
  /// If the app is not used for this long, the reminders stop instead of
  /// showing a stale amount.
  static const int morningReminderDays = 7;

  /// Notification id of the morning reminder [dayOffset] mornings after the
  /// next one (0 = the next one, which keeps [morningReminderId]).
  static int morningReminderIdFor(int dayOffset) =>
      dayOffset == 0 ? morningReminderId : 1100 + dayOffset;
  static const int testNotificationId = 1999;

  static const String channelId = 'budget_reminders';
  static const String channelName = 'Budget Reminders';

  /// Android small-icon resource (android/app/src/main/res/drawable/).
  /// Must be a monochrome, transparent-background drawable.
  static const String notificationIcon = '@drawable/ic_notification';

  /// Brand accent used by Android to tint the small icon in the shade.
  static const Color notificationColor = Color(0xFF0D2477);

  static const String channelDescription =
      "Daily Today's Safe Spending reminder and evening summary";

  /// Payload of a Pay later reminder: this prefix, then the tab id.
  static const String payLaterPayloadPrefix = 'pay_later:';

  /// The tab a Pay later reminder [payload] is for; null for any other
  /// notification (bill and daily notifications are not routed).
  static String? payLaterTabIdFrom(String? payload) {
    if (payload == null || !payload.startsWith(payLaterPayloadPrefix)) {
      return null;
    }
    final tabId = payload.substring(payLaterPayloadPrefix.length);
    return tabId.isEmpty ? null : tabId;
  }

  // Status-bar icons are alpha-masked by Android, so the launcher PNG would
  // render as a solid square. Use the dedicated monochrome vector instead.
  static const InitializationSettings _initializationSettings =
      InitializationSettings(
        android: AndroidInitializationSettings(notificationIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

  final FlutterLocalNotificationsPlugin _plugin;
  final GetSpendingTargetsUseCase spendingTargetsUseCase;

  /// Puts back the bill reminders [scheduleAll] clears. The plugin can only
  /// clear every pending notification at once (per-id cancel also removes
  /// one already shown), and bill reminders share it, so without this every
  /// re-schedule (after any expense, budget or bill change) silently drops
  /// them.
  final Future<void> Function()? rescheduleBillReminders;

  /// Puts back the Pay later reminders [scheduleAll] clears, for the same
  /// reason as [rescheduleBillReminders].
  final Future<void> Function() rescheduleTabReminders;

  /// Opens a tab's screen when its reminder is tapped, also when the tap
  /// launched the app.
  final void Function(String tabId) onPayLaterTap;

  /// Source of "now" for scheduling. Tests inject a fixed clock.
  final DateTime Function() _clock;
  bool _initialized = false;
  bool _launchTapChecked = false;
  bool _timeZonesConfigured = false;

  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    required this.spendingTargetsUseCase,
    this.rescheduleBillReminders,
    required this.rescheduleTabReminders,
    required this.onPayLaterTap,
    DateTime Function()? clock,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _clock = clock ?? DateTime.now;

  /// Initializes the plugin, timezone database, and Android notification channel.
  Future<bool> initialize() async {
    if (_initialized) return true;

    debugPrint('[Notifications] Initializing');

    await _configureLocalTimeZone();

    debugPrint('[Notifications] Timezone initialized');
    final ok = await _plugin.initialize(
      _initializationSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
    );
    // Whatever initialize answered: iOS answers false when no permission is
    // requested (never, here), and the launch tap is there all the same.
    if (!_launchTapChecked) {
      _launchTapChecked = true;
      await _routeLaunchTap();
    }
    if (ok != true) {
      return false;
    }

    await _createAndroidNotificationChannel();
    _initialized = true;
    debugPrint('[Notifications] Plugin initialized');
    return true;
  }

  /// A tap on a notification while the app was not running launches it
  /// without calling the tap handler; the plugin keeps it as launch details.
  /// Read once, right after the first initialize call.
  Future<void> _routeLaunchTap() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return;
      final response = details.notificationResponse;
      if (response != null) handleNotificationResponse(response);
    } catch (e) {
      // The app opens on its usual screen.
      debugPrint('[Notification] Could not read the launch notification: $e');
    }
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

  /// Schedules all daily notifications based on [settings].
  ///
  /// The morning notification is scheduled once per day for the next
  /// [morningReminderDays] mornings, each body calculated for the day it
  /// fires using [GetTodaySafeSpendingUseCase].
  ///
  /// Clearing the pending schedule also clears bill and Pay later
  /// reminders, which are opted into per bill or tab (not by these
  /// settings), so they are put back through [rescheduleBillReminders] and
  /// [rescheduleTabReminders] straight away.
  Future<void> scheduleAll(AppSettings settings) async {
    await initialize();
    await cancelAllPending();
    await _restoreBillReminders();
    await _restoreTabReminders();

    final notifSettings = settings.notifications;
    if (!notifSettings.notificationsEnabled) return;

    if (notifSettings.morningReminderEnabled) {
      await _scheduleMorningReminders(
        hour: notifSettings.morningReminderTime.hour,
        minute: notifSettings.morningReminderTime.minute,
      );
    }

    if (notifSettings.eveningSummaryEnabled) {
      await _scheduleDailyNotification(
        id: eveningSummaryId,
        title: 'Evening Summary 🌙',
        body: "Review today's expenses and check how each budget is doing.",
        hour: notifSettings.eveningSummaryTime.hour,
        minute: notifSettings.eveningSummaryTime.minute,
      );
    }
  }

  /// The morning text when the amounts could not be worked out: the same
  /// neutral line the home-screen widget shows, not "no budget".
  static const String morningUnavailableBody =
      "Open Monivo to see today's safe spending.";

  /// The morning notification text for the budgets running today, one line
  /// per budget (never combined).
  ///
  /// The amount is Today's Safe Spending floored to the shown digits, so it
  /// never reads higher than what is safe. When nothing is free to spend,
  /// the text says why (over budget, or bills and money set aside exceed
  /// what's left) instead of "you can safely spend ₹0".
  static String morningBody(List<BudgetDailyLimitEntity> limits) {
    if (limits.isEmpty) {
      return 'No budget is running today. Open the app to check your budgets.';
    }
    if (limits.length == 1) {
      // Single budget — show simple message.
      final bl = limits.first;
      if (_nothingFree(bl)) return _nothingFreeSentence(bl);
      return '${bl.budgetName}: you can safely spend '
          '${CurrencyFormatter.formatFloored(bl.dailyLimit, code: bl.currency)} '
          'today.';
    }
    // Multiple budgets — one line per budget, never combined.
    final lines = limits
        .map(
          (bl) =>
              '${bl.budgetName}: '
              '${_nothingFree(bl) ? _nothingFreeShort(bl) : CurrencyFormatter.formatFloored(bl.dailyLimit, code: bl.currency)}',
        )
        .join('\n');
    return "Today's Safe Spending per budget\n\n$lines";
  }

  /// Whether the daily amount shows as zero.
  static bool _nothingFree(BudgetDailyLimitEntity bl) =>
      CurrencyFormatter.floorForDisplay(
        bl.dailyLimit,
        code: bl.currency,
      ).amount <=
      0;

  static String _nothingFreeSentence(BudgetDailyLimitEntity bl) {
    final entity = bl.safeToSpend;
    String amount(double value) =>
        CurrencyFormatter.format(value, code: bl.currency);
    switch (entity?.status) {
      case SafeToSpendStatus.overBudget:
        return "${bl.budgetName}: you've spent "
            '${amount(-entity!.availableBalance)} more than this budget\'s '
            'amount. Nothing is free to spend today.';
      case SafeToSpendStatus.overcommitted:
        return '${bl.budgetName}: bills and money set aside are '
            "${amount(entity!.shortfall)} more than what's left. Nothing is "
            'free to spend today.';
      default:
        if (entity != null && entity.totalDeductions > 0) {
          return '${bl.budgetName}: nothing is free to spend today after '
              'bills and money set aside.';
        }
        return '${bl.budgetName}: nothing is free to spend today.';
    }
  }

  static String _nothingFreeShort(BudgetDailyLimitEntity bl) {
    final entity = bl.safeToSpend;
    String amount(double value) =>
        CurrencyFormatter.format(value, code: bl.currency);
    return switch (entity?.status) {
      SafeToSpendStatus.overBudget =>
        '${amount(-entity!.availableBalance)} over budget',
      SafeToSpendStatus.overcommitted => '${amount(entity!.shortfall)} short',
      _ => 'nothing free to spend',
    };
  }

  /// Schedules a one-off test notification one minute from now.
  ///
  /// Intended for development verification of permission, channel, and delivery.
  /// Uses the same per-budget calculation as the morning notification.
  Future<void> scheduleTestNotification() async {
    await initialize();

    final perBudget = await _getPerBudgetSafeSpending();

    final body = perBudget == null
        ? morningUnavailableBody
        : morningBody(perBudget.budgetLimits);

    debugPrint('[Notification] Test notification body: $body');

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      icon: notificationIcon,
      color: notificationColor,
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
      "Today's Safe Spending",
      CurrencyFormatter.forSystemText(body),
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _restoreBillReminders() async {
    final reschedule = rescheduleBillReminders;
    if (reschedule == null) return;
    try {
      await reschedule();
    } catch (e) {
      // The daily notifications still get scheduled.
      debugPrint('[Notification] Could not restore bill reminders: $e');
    }
  }

  Future<void> _restoreTabReminders() async {
    try {
      await rescheduleTabReminders();
    } catch (e) {
      // The daily notifications still get scheduled.
      debugPrint('[Notification] Could not restore pay later reminders: $e');
    }
  }

  /// Cancels scheduled notifications without touching already displayed ones.
  Future<void> cancelAllPending() async {
    await _cancelWithRecovery(() => _plugin.cancelAllPendingNotifications());
  }

  /// Whether the plugin is ready for scheduling.
  bool get isInitialized => _initialized;

  /// Schedules the Today's Safe Spending reminder for each of the next
  /// [morningReminderDays] mornings at [hour]:[minute], each body calculated
  /// for the day it fires. A reminder scheduled in the evening is for
  /// tomorrow, so it carries tomorrow's amount (today's spending already
  /// counted, one day fewer to spread it over), not today's.
  Future<void> _scheduleMorningReminders({
    required int hour,
    required int minute,
  }) async {
    final first = _nextInstanceOf(hour, minute);
    for (var i = 0; i < morningReminderDays; i++) {
      // Calendar arithmetic, so a daylight-saving change keeps the time.
      final day = DateTime(first.year, first.month, first.day + i);
      final perBudget = await _getPerBudgetSafeSpending(referenceDate: day);
      final body = perBudget == null
          ? morningUnavailableBody
          : morningBody(perBudget.budgetLimits);

      debugPrint('[Notification] Morning notification for $day: $body');

      await _schedule(
        id: morningReminderIdFor(i),
        title: "Today's Safe Spending",
        body: body,
        at: tz.TZDateTime(tz.local, day.year, day.month, day.day, hour, minute),
      );
    }
  }

  /// Schedules a notification repeating every day at [hour]:[minute]. Only
  /// for text that does not depend on the day.
  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) {
    return _schedule(
      id: id,
      title: title,
      body: body,
      at: _nextInstanceOf(hour, minute),
      repeatDaily: true,
    );
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    bool repeatDaily = false,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      icon: notificationIcon,
      color: notificationColor,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // The system draws notifications with its own fonts.
    await _plugin.zonedSchedule(
      id,
      CurrencyFormatter.forSystemText(title),
      CurrencyFormatter.forSystemText(body),
      at,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
    );
  }

  /// The next [hour]:[minute] from now: today if it is still ahead,
  /// otherwise tomorrow.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.from(_clock(), tz.local);
    final today = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!today.isBefore(now)) return today;
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }

  /// Fetches per-budget safe spending using the same business logic as the
  /// Dashboard's "Today's Spending Limits" section, for [referenceDate]
  /// (today when omitted).
  Future<PerBudgetSafeSpendingResult?> _getPerBudgetSafeSpending({
    DateTime? referenceDate,
  }) async {
    try {
      final useCase = GetTodaySafeSpendingUseCase(
        spendingTargetsUseCase: spendingTargetsUseCase,
      );
      return await useCase.callPerBudget(referenceDate: referenceDate);
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
        '[Notifications] Resolved timezone: ${timezoneInfo.identifier}',
      );
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e, st) {
      debugPrint('[Notifications] Failed to resolve local timezone: $e\n$st');
      debugPrint('[Notifications] Falling back to UTC');
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

  /// The app's one notification tap handler. The plugin keeps only the
  /// handler of its latest initialize call, so every initialize in the app
  /// (this service's and the bill reminders') passes this one. A Pay later
  /// reminder opens its tab; everything else is only logged, as before.
  void handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final tabId = payLaterTabIdFrom(payload);
    if (tabId != null) {
      try {
        onPayLaterTap(tabId);
      } catch (e) {
        debugPrint('[Notification] Could not open the tab: $e');
      }
      return;
    }

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
