import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/currency/money_math.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../settings/domain/services/notification_service.dart';
import '../../domain/entities/pay_later_failure.dart';
import '../../domain/entities/pay_later_tab.dart';
import '../../domain/entities/settle_rhythm.dart';
import '../../domain/entities/tab_ledger.dart';
import '../../domain/services/pay_later_ledger.dart';
import '../../domain/usecases/get_tab_ledger_usecase.dart';
import '../../domain/usecases/get_tabs_usecase.dart';

/// Schedules one settle-up reminder per tab (spec §8): on the settle-up day
/// minus the tab's offset, at [reminderHour]:00 local time; once that moment
/// has passed, for the following settle-up ([reminderFor]).
///
/// Reads only. It holds no payment or write use case, so a reminder can
/// never record a payment.
///
/// Every Pay later write notifies [RefreshBuses.payLater], and a new day
/// notifies [RefreshBuses.day]; once [start]ed the service listens to both
/// and re-schedules every tab (bursts collapse into one run). Runs never
/// overlap. A failure is logged and never thrown to the caller.
///
/// The plugin is never initialized here: it keeps only the tap handler of
/// its latest `initialize` call, and every call in the app passes
/// [NotificationService.handleNotificationResponse] (that is how a tap opens
/// the tab). Scheduling needs only the time zone and the channel.
class TabReminderService {
  static const String channelId = 'pay_later_reminders';
  static const String channelName = 'Pay later reminders';
  static const String channelDescription =
      "Reminders before a tab's settle-up day";

  /// Reminders fire at this hour, local time, like the morning reminder's
  /// default.
  static const int reminderHour = 9;

  /// Notification ids are [notificationIdBase] + a stable hash of the tab
  /// id below 10,000,000: clear of the daily notifications (1001–1999) and
  /// of bill reminders (80,000,000–89,999,999).
  static const int notificationIdBase = 90000000;

  static const String reminderTitle = 'Settle-up reminder';

  /// How long a burst of changes is collected before one re-schedule.
  static const Duration defaultDebounce = Duration(milliseconds: 500);

  /// The app-wide buses that make the reminders stale.
  static List<RefreshBus> get defaultTriggers => [
    RefreshBuses.payLater,
    RefreshBuses.day,
  ];

  final FlutterLocalNotificationsPlugin _plugin;
  final GetTabsUseCase getTabs;
  final GetTabLedgerUseCase getLedger;
  final DateTime Function() _clock;
  final Duration _debounce;
  final List<RefreshBus> _triggers;

  final List<StreamSubscription<void>> _subscriptions = [];
  Timer? _debounceTimer;
  bool _ready = false;

  /// The end of the last queued job; every job waits for it.
  Future<void> _tail = Future<void>.value();

  /// A [rescheduleAll] queued but not started yet; later calls share it.
  Future<void>? _queuedAll;

  TabReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    required this.getTabs,
    required this.getLedger,
    DateTime Function()? clock,
    Duration debounce = defaultDebounce,
    List<RefreshBus>? triggers,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _clock = clock ?? DateTime.now,
       _debounce = debounce,
       _triggers = triggers ?? defaultTriggers;

  /// The notification id of [tabId]'s reminder.
  static int notificationIdFor(String tabId) {
    var hash = 0;
    for (var i = 0; i < tabId.length; i++) {
      hash = (hash * 31 + tabId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return notificationIdBase + hash % 10000000;
  }

  /// The payload a tap is routed by ([NotificationService.payLaterTabIdFrom]).
  static String payloadFor(String tabId) =>
      '${NotificationService.payLaterPayloadPrefix}$tabId';

  /// The text, for the day it fires: [fireDay] → [settleUp] when given,
  /// else [PayLaterTab.reminderOffsetDays] before the settle-up day. No
  /// amount: it would be stale by then.
  static String reminderBody(
    PayLaterTab tab, {
    DateTime? fireDay,
    DateTime? settleUp,
  }) {
    final days = fireDay != null && settleUp != null
        ? calendarDaysBetween(fireDay, settleUp)
        : _offsetOf(tab);
    if (days <= 0) return '${tab.name}: settle-up day';
    return '${tab.name}: settle-up in $days ${days == 1 ? 'day' : 'days'}';
  }

  /// The day [tab]'s reminder fires (local midnight). See [reminderFor].
  static DateTime? reminderDayFor(
    PayLaterTab tab,
    TabLedger ledger,
    DateTime now,
  ) => reminderFor(tab, ledger, now)?.fireDay;

  /// When [tab]'s reminder fires and the settle-up day it is for: the
  /// earliest settle-up day whose reminder moment ([reminderHour]:00 on the
  /// settle-up day minus the offset) is not before [now]. When the nearest
  /// settle-up's moment has passed, that is a following settle-up (no late
  /// reminder: nothing records that one already went off). Null when the
  /// reminder is off, the tab is archived or on demand, nothing is owed, a
  /// manual date is needed, or a manual date has no later date to remind
  /// about.
  static ({DateTime fireDay, DateTime settleUp})? reminderFor(
    PayLaterTab tab,
    TabLedger ledger,
    DateTime now,
  ) {
    if (!tab.reminderEnabled || tab.isArchived) return null;
    if (tab.rhythm is OnDemand) return null;
    if (MoneyMath.forCurrency(tab.currency).toUnits(ledger.owed) <= 0) {
      return null;
    }
    if (ledger.needsSettleDate || ledger.nextSettleUp == null) return null;

    final offset = _offsetOf(tab);
    final today = now.dateOnly;
    final todayMoment = DateTime(
      today.year,
      today.month,
      today.day,
      reminderHour,
    );
    // The first day a reminder can still fire on.
    final firstFireDay = todayMoment.isBefore(now) ? today.addDays(1) : today;
    // Settle-up days only grow, so the first one on or after this day is
    // the nearest settle-up whose reminder is still ahead; one with nothing
    // due on it (the same rule the screens use) is skipped.
    final settleUp = PayLaterLedger.nextSettleUpDue(
      tab.rhythm,
      firstFireDay.addDays(offset),
      ledger.purchases,
      MoneyMath.forCurrency(tab.currency),
    );
    if (settleUp == null) return null;
    return (fireDay: settleUp.addDays(-offset), settleUp: settleUp);
  }

  static int _offsetOf(PayLaterTab tab) =>
      tab.reminderOffsetDays < 0 ? 0 : tab.reminderOffsetDays;

  /// Listens for Pay later and day changes, and queues one re-schedule now.
  /// Calling it again does nothing.
  void start() {
    if (_subscriptions.isNotEmpty) return;
    for (final bus in _triggers) {
      _subscriptions.add(bus.changes.listen((_) => _queueReschedule()));
    }
    _queueReschedule();
  }

  /// Stops listening. Queued work still finishes.
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _queueReschedule() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _debounceTimer = null;
      unawaited(rescheduleAll());
    });
  }

  /// Schedules or cancels [tabId]'s reminder.
  Future<void> sync(String tabId) => _enqueue('sync $tabId', () async {
    await _ensureReady();
    final pending = await _pendingTabReminders();
    final result = await getLedger(tabId);
    switch (result) {
      case PayLaterSuccess(:final data):
        await _apply(data.tab, data, pending);
      case PayLaterError(:final failure)
          when failure.type == PayLaterErrorType.notFound:
        // Deleted: nothing to remind about.
        await _cancelIfPending(notificationIdFor(tabId), pending);
      case PayLaterError(:final failure):
        // Keep what is scheduled; the next change tries again.
        _log('Could not load tab $tabId: ${failure.message}');
    }
  });

  /// Schedules or cancels every tab's reminder, and cancels the pending
  /// reminder of a tab that no longer exists. Calls made while one is
  /// waiting to start share it.
  Future<void> rescheduleAll() {
    final queued = _queuedAll;
    if (queued != null) return queued;
    late final Future<void> run;
    run = _enqueue('reschedule all', () async {
      if (identical(_queuedAll, run)) _queuedAll = null;
      await _rescheduleAllNow();
    });
    _queuedAll = run;
    return run;
  }

  Future<void> _rescheduleAllNow() async {
    await _ensureReady();
    final result = await getTabs();
    final List<PayLaterTab> tabs;
    switch (result) {
      case PayLaterSuccess(:final data):
        tabs = data;
      case PayLaterError(:final failure):
        // Keep what is scheduled; the next change tries again.
        _log('Could not load tabs: ${failure.message}');
        return;
    }

    final pending = await _pendingTabReminders();
    final known = <int>{};
    for (final tab in tabs) {
      known.add(notificationIdFor(tab.id));
      if (_cannotRemind(tab)) {
        // No ledger needed to know there is nothing to remind about.
        await _cancelIfPending(notificationIdFor(tab.id), pending);
        continue;
      }
      final ledger = await getLedger(tab.id);
      switch (ledger) {
        case PayLaterSuccess(:final data):
          await _apply(tab, data, pending);
        case PayLaterError(:final failure):
          _log('Could not load tab ${tab.id}: ${failure.message}');
      }
    }

    if (pending == null) return;
    for (final id in pending) {
      if (!known.contains(id)) await _cancel(id);
    }
  }

  static bool _cannotRemind(PayLaterTab tab) =>
      !tab.reminderEnabled || tab.isArchived || tab.rhythm is OnDemand;

  Future<void> _apply(
    PayLaterTab tab,
    TabLedger ledger,
    Set<int>? pending,
  ) async {
    final id = notificationIdFor(tab.id);
    final reminder = reminderFor(tab, ledger, _clock());
    if (reminder == null) {
      await _cancelIfPending(id, pending);
      return;
    }
    await _schedule(tab, id, reminder.fireDay, reminder.settleUp);
  }

  Future<void> _schedule(
    PayLaterTab tab,
    int id,
    DateTime day,
    DateTime settleUp,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        icon: NotificationService.notificationIcon,
        color: NotificationService.notificationColor,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    final at = tz.TZDateTime(
      tz.local,
      day.year,
      day.month,
      day.day,
      reminderHour,
    );
    try {
      // Same id: replaces the tab's earlier reminder.
      await _plugin.zonedSchedule(
        id,
        reminderTitle,
        reminderBody(tab, fireDay: day, settleUp: settleUp),
        at,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payloadFor(tab.id),
      );
    } catch (e) {
      _log('Could not schedule the reminder for tab ${tab.id}: $e');
    }
  }

  /// Ids of the Pay later reminders still waiting to fire; null when the
  /// platform can't say.
  Future<Set<int>?> _pendingTabReminders() async {
    try {
      final requests = await _plugin.pendingNotificationRequests();
      return {
        for (final request in requests)
          if (NotificationService.payLaterTabIdFrom(request.payload) != null)
            request.id,
      };
    } catch (e) {
      _log('Could not read pending reminders: $e');
      return null;
    }
  }

  /// Cancels only a reminder still waiting: cancelling by id also takes one
  /// already shown out of the notification shade.
  Future<void> _cancelIfPending(int id, Set<int>? pending) async {
    if (pending != null && !pending.contains(id)) return;
    await _cancel(id);
  }

  Future<void> _cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      _log('Could not cancel reminder $id: $e');
    }
  }

  /// Runs [job] after every job queued before it, so runs never overlap.
  Future<void> _enqueue(String what, Future<void> Function() job) {
    final next = _tail.then((_) => job()).catchError((Object e, StackTrace s) {
      _log('Failed to $what: $e', error: e, stackTrace: s);
    });
    _tail = next;
    return next;
  }

  /// The time zone and the Android channel. Never the plugin itself (see
  /// the class comment).
  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      _log('Could not resolve the time zone, using UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              channelName,
              description: channelDescription,
              importance: Importance.high,
            ),
          );
    } catch (e) {
      _log('Could not create the reminder channel: $e');
    }
    _ready = true;
  }

  static void _log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'TabReminders',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
