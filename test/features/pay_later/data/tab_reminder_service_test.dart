import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/dates/calendar_dates.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/pay_later/data/services/tab_reminder_service.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/payment_allocation.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_ledger.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tab_ledger_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tabs_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/manage_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_payment_usecase.dart';
import 'package:monivo/features/settings/domain/services/notification_service.dart';

import '../../../helpers/pay_later_fixtures.dart';
import '../../../helpers/pay_later_memory_repository.dart';

/// One scheduled notification as the platform would hold it.
class _Scheduled {
  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime at;
  final String? payload;
  final AndroidScheduleMode mode;

  _Scheduled(this.id, this.title, this.body, this.at, this.payload, this.mode);
}

/// The plugin as the platform behaves: one pending set, replaced by id.
class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final Map<int, _Scheduled> pending = {};
  final List<int> cancelled = [];
  int scheduleCalls = 0;
  int initializeCalls = 0;

  /// Makes [pendingNotificationRequests] throw, as the platform store can.
  bool pendingUnreadable = false;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCalls++;
    return true;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduleCalls++;
    pending[id] = _Scheduled(
      id,
      title,
      body,
      scheduledDate,
      payload,
      androidScheduleMode,
    );
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    if (pendingUnreadable) throw Exception('Missing type parameter');
    return [
      for (final s in pending.values)
        PendingNotificationRequest(s.id, s.title, s.body, s.payload),
    ];
  }
}

/// Counts reads and can hold [getTabs] open, to see runs overlap.
class _CountingRepository extends MemoryPayLaterRepository {
  int getTabsCalls = 0;
  int inFlight = 0;
  int maxInFlight = 0;
  Completer<void>? gate;
  Object? tabsError;

  @override
  Future<List<PayLaterTab>> getTabs() async {
    getTabsCalls++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      final g = gate;
      if (g != null) await g.future;
      final error = tabsError;
      if (error != null) throw error;
      return super.getTabs();
    } finally {
      inFlight--;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 2 Nov 2026, 08:00 local.
  var now = DateTime(2026, 11, 2, 8);
  DateTime clock() => now;

  late _CountingRepository repo;
  late _FakePlugin plugin;
  late TabReminderService service;

  /// A tab settling on day 10 of each month, so the next settle-up from
  /// 2 Nov is 10 Nov.
  PayLaterTab monthlyTab(
    String id, {
    int offset = 2,
    bool reminder = true,
    String name = 'Campus cafeteria',
  }) => payLaterTab(
    id,
    rhythm: const MonthlyDay(day: 10),
    name: name,
  ).copyWith(reminderEnabled: reminder, reminderOffsetDays: offset);

  TabReminderService build({
    Duration debounce = Duration.zero,
    List<RefreshBus>? triggers,
  }) => TabReminderService(
    plugin: plugin,
    getTabs: GetTabsUseCase(repository: repo),
    getLedger: GetTabLedgerUseCase(repository: repo, clock: clock),
    clock: clock,
    debounce: debounce,
    triggers: triggers ?? const [],
  );

  Future<TabLedger> ledgerOf(String tabId) async {
    final result = await GetTabLedgerUseCase(repository: repo, clock: clock)(
      tabId,
    );
    return (result as PayLaterSuccess<TabLedger>).data;
  }

  int idOf(String tabId) => TabReminderService.notificationIdFor(tabId);

  setUp(() {
    now = DateTime(2026, 11, 2, 8);
    repo = _CountingRepository();
    plugin = _FakePlugin();
    service = build();
  });

  tearDown(() => service.dispose());

  group('what gets scheduled (brief step 1)', () {
    test('no reminder when owed is 0', () async {
      repo.addTab(monthlyTab('t1'));

      await service.sync('t1');
      await service.rescheduleAll();

      expect(plugin.pending, isEmpty);
    });

    test('offset 2 schedules two days before, at 09:00 local', () async {
      repo
        ..addTab(monthlyTab('t1', offset: 2))
        ..addPurchase('t1', payLaterExpense('e1', amount: 5));

      await service.sync('t1');

      final scheduled = plugin.pending[idOf('t1')]!;
      // Settle-up 10 Nov − 2 days.
      expect(
        (
          scheduled.at.year,
          scheduled.at.month,
          scheduled.at.day,
          scheduled.at.hour,
          scheduled.at.minute,
        ),
        (2026, 11, 8, 9, 0),
      );
      expect(scheduled.at.location, tz.local);
      expect(scheduled.payload, 'pay_later:t1');
      expect(scheduled.mode, AndroidScheduleMode.inexactAllowWhileIdle);
    });

    test('on demand never schedules', () async {
      repo
        ..addTab(
          payLaterTab(
            't1',
          ).copyWith(reminderEnabled: true, reminderOffsetDays: 0),
        )
        ..addPurchase('t1', payLaterExpense('e1', amount: 5));

      await service.sync('t1');
      await service.rescheduleAll();

      expect(plugin.pending, isEmpty);
    });

    test('payment that clears the tab cancels the reminder', () async {
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1', amount: 5));
      await service.sync('t1');
      expect(plugin.pending.keys, [idOf('t1')]);

      // The user pays in full through the app's own payment path.
      final paid = await TabPaymentUseCase(
        repository: repo,
        reconcileTab: ReconcileTabUseCase(repository: repo),
        clock: clock,
      ).record(paymentId: 'p1', tabId: 't1', amount: 5, paidDate: now);
      expect(paid, isA<PayLaterSuccess>());

      await service.sync('t1');

      expect(plugin.pending, isEmpty);
      expect(plugin.cancelled, [idOf('t1')]);
    });

    test('body contains no amount', () async {
      repo
        ..addTab(monthlyTab('t1', offset: 2))
        ..addPurchase('t1', payLaterExpense('e1', amount: 12.345));

      await service.sync('t1');

      final scheduled = plugin.pending[idOf('t1')]!;
      expect(scheduled.body, 'Campus cafeteria: settle-up in 2 days');
      for (final text in [scheduled.title!, scheduled.body!]) {
        expect(text, isNot(contains('12')));
        expect(text, isNot(contains('OMR')));
        expect(
          text,
          isNot(contains(CurrencyFormatter.format(12.345, code: 'OMR'))),
        );
      }
    });
  });

  test('write on settle-up day after 09:00 schedules the next period\'s '
      'reminder', () async {
    // QA F1: every 14 days from 2 Nov, a purchase at 13:40 on 2 Nov.
    now = DateTime(2026, 11, 2, 13, 40);
    repo
      ..addTab(
        payLaterTab(
          't1',
          rhythm: EveryDays(days: 14, anchor: DateTime(2026, 11, 2)),
        ).copyWith(reminderEnabled: true, reminderOffsetDays: 0),
      )
      ..addPurchase('t1', payLaterExpense('e1', amount: 1.5));

    await service.rescheduleAll();

    final scheduled = plugin.pending[idOf('t1')]!;
    expect(
      (scheduled.at.year, scheduled.at.month, scheduled.at.day),
      (2026, 11, 16),
    );
    expect(scheduled.at.hour, 9);
    expect(scheduled.body, 'Cafeteria: settle-up day');
  });

  group('reminder text', () {
    test('offset 0 says settle-up day', () {
      expect(
        TabReminderService.reminderBody(monthlyTab('t1', offset: 0)),
        'Campus cafeteria: settle-up day',
      );
    });

    test('offset 1 is singular', () {
      expect(
        TabReminderService.reminderBody(monthlyTab('t1', offset: 1)),
        'Campus cafeteria: settle-up in 1 day',
      );
    });

    test('offset 3 counts the days', () {
      expect(
        TabReminderService.reminderBody(monthlyTab('t1', offset: 3)),
        'Campus cafeteria: settle-up in 3 days',
      );
    });

    test('the day count is taken from the day it fires', () {
      expect(
        TabReminderService.reminderBody(
          monthlyTab('t1', offset: 3),
          fireDay: DateTime(2026, 11, 8),
          settleUp: DateTime(2026, 11, 10),
        ),
        'Campus cafeteria: settle-up in 2 days',
      );
      expect(
        TabReminderService.reminderBody(
          monthlyTab('t1', offset: 3),
          fireDay: DateTime(2026, 11, 10),
          settleUp: DateTime(2026, 11, 10),
        ),
        'Campus cafeteria: settle-up day',
      );
    });
  });

  group('reminderDayFor', () {
    Future<DateTime?> dayFor(PayLaterTab tab, {double? purchase = 5}) async {
      repo.tabs.clear();
      repo.purchases.clear();
      repo.addTab(tab);
      if (purchase != null) {
        repo.addPurchase(tab.id, payLaterExpense('e1', amount: purchase));
      }
      return TabReminderService.reminderDayFor(
        tab,
        await ledgerOf(tab.id),
        now,
      );
    }

    test('settle-up minus the offset, at local midnight', () async {
      expect(await dayFor(monthlyTab('t1', offset: 2)), DateTime(2026, 11, 8));
      expect(await dayFor(monthlyTab('t1', offset: 0)), DateTime(2026, 11, 10));
    });

    test('null when the reminder is off', () async {
      expect(await dayFor(monthlyTab('t1', reminder: false)), isNull);
    });

    test('null on demand', () async {
      expect(
        await dayFor(payLaterTab('t1').copyWith(reminderEnabled: true)),
        isNull,
      );
    });

    test('null when nothing is owed', () async {
      expect(await dayFor(monthlyTab('t1'), purchase: null), isNull);
    });

    test('null when a manual date is needed', () async {
      final tab = payLaterTab(
        't1',
        rhythm: ManualDate(anchor: DateTime(2026, 10, 1)),
      ).copyWith(reminderEnabled: true);
      expect(await dayFor(tab), isNull);
    });

    test('null for an archived tab', () async {
      expect(await dayFor(monthlyTab('t1').copyWith(isArchived: true)), isNull);
    });

    test('reminder day passed (offset > days left): the following '
        "settle-up's reminder, no late one", () async {
      // Settle-up 10 Nov − 9 days = 1 Nov, before today: 10 Dec − 9 days.
      expect(await dayFor(monthlyTab('t1', offset: 9)), DateTime(2026, 12, 1));
      // Offset 7 from 5 Nov: 10 Nov − 7 = 3 Nov has passed → 3 Dec.
      now = DateTime(2026, 11, 5, 8);
      expect(await dayFor(monthlyTab('t1', offset: 7)), DateTime(2026, 12, 3));
      // Offset 5 from 5 Nov at 08:00: 10 Nov − 5 = 5 Nov 09:00 still ahead.
      expect(await dayFor(monthlyTab('t1', offset: 5)), DateTime(2026, 11, 5));
    });

    test('on the settle-up day with offset 0: today before 09:00, the '
        'following settle-up after', () async {
      now = DateTime(2026, 11, 10, 8, 59);
      expect(await dayFor(monthlyTab('t1', offset: 0)), DateTime(2026, 11, 10));

      now = DateTime(2026, 11, 10, 9, 1);
      expect(await dayFor(monthlyTab('t1', offset: 0)), DateTime(2026, 12, 10));
    });

    // Paid what settles on 10 Nov the day before, then bought on 10 Nov
    // before 09:00: nothing is due on 10 Nov, so no "settle-up day" ping.
    test('on the settle-up day with nothing due on it: the following '
        'settle-up, even before 09:00', () async {
      now = DateTime(2026, 11, 10, 8);
      final tab = monthlyTab('t1', offset: 0);
      repo.tabs.clear();
      repo.purchases.clear();
      repo.addTab(tab);
      repo.addPurchase('t1', payLaterExpense('old', amount: 1.5));
      repo.addPurchase(
        't1',
        payLaterExpense('new', amount: 2).copyWith(
          date: DateTime(2026, 11, 10),
          time: DateTime(2026, 11, 10, 7, 30),
        ),
      );
      repo.payments['p1'] = TabPayment(
        id: 'p1',
        tabId: 't1',
        amount: 1.5,
        paidDate: DateTime(2026, 11, 9),
        createdAt: DateTime(2026, 11, 9),
        updatedAt: DateTime(2026, 11, 9),
      );
      repo.allocations['p1:old'] = PaymentAllocation(
        id: 'p1:old',
        paymentId: 'p1',
        expenseId: 'old',
        amount: 1.5,
        isManual: false,
        createdAt: DateTime(2026, 11, 9),
      );
      final ledger = await ledgerOf('t1');
      expect(ledger.owed, 2);
      expect(
        TabReminderService.reminderDayFor(tab, ledger, now),
        DateTime(2026, 12, 10),
      );

      // Still owing on what settles on 10 Nov: today's reminder stands.
      repo.allocations['p1:old'] = repo.allocations['p1:old']!.copyWith(
        amount: 1,
      );
      expect(
        TabReminderService.reminderDayFor(tab, await ledgerOf('t1'), now),
        DateTime(2026, 11, 10),
      );
    });

    test('every 14 days: on the settle-up day after 09:00 the next '
        "period's reminder", () async {
      now = DateTime(2026, 11, 2, 13, 40);
      final tab = payLaterTab(
        't1',
        rhythm: EveryDays(days: 14, anchor: DateTime(2026, 11, 2)),
      ).copyWith(reminderEnabled: true, reminderOffsetDays: 0);
      expect(await dayFor(tab), DateTime(2026, 11, 16));
      // A short period with a long offset skips as many periods as needed.
      final daily = payLaterTab(
        't1',
        rhythm: EveryDays(days: 1, anchor: DateTime(2026, 11, 2)),
      ).copyWith(reminderEnabled: true, reminderOffsetDays: 3);
      // Earliest fire day is tomorrow (3 Nov): settle-up 6 Nov − 3.
      expect(await dayFor(daily), DateTime(2026, 11, 3));
    });

    test('manual date with no later date: none once its moment has '
        'passed', () async {
      final tab = payLaterTab(
        't1',
        rhythm: ManualDate(
          anchor: DateTime(2026, 10, 20),
          nextSettleDate: DateTime(2026, 11, 2),
        ),
      ).copyWith(reminderEnabled: true, reminderOffsetDays: 0);
      now = DateTime(2026, 11, 2, 8);
      expect(await dayFor(tab), DateTime(2026, 11, 2));
      now = DateTime(2026, 11, 2, 9, 30);
      expect(await dayFor(tab), isNull);
      // Offset 3, set date in 2 days: its reminder day has passed.
      final soon = payLaterTab(
        't1',
        rhythm: ManualDate(
          anchor: DateTime(2026, 10, 20),
          nextSettleDate: DateTime(2026, 11, 4),
        ),
      ).copyWith(reminderEnabled: true, reminderOffsetDays: 3);
      expect(await dayFor(soon), isNull);
    });

    test('on demand stays none', () async {
      now = DateTime(2026, 11, 2, 13);
      expect(
        await dayFor(
          payLaterTab(
            't1',
          ).copyWith(reminderEnabled: true, reminderOffsetDays: 0),
        ),
        isNull,
      );
    });

    test('steps calendar days across a daylight-saving change', () async {
      // Clocks go back in New York on 1 Nov 2026 and in Europe on 25 Oct.
      now = DateTime(2026, 10, 21, 8);
      final tab = payLaterTab(
        't1',
        rhythm: EveryDays(days: 14, anchor: DateTime(2026, 10, 20)),
      ).copyWith(reminderEnabled: true, reminderOffsetDays: 7);
      // Settle-up 3 Nov − 7 days = 27 Oct.
      expect(await dayFor(tab), DateTime(2026, 10, 27));
    });
  });

  group('ids and payloads', () {
    test('the id is stable and outside every other notification range', () {
      final id = idOf('tab-uuid-1');
      expect(idOf('tab-uuid-1'), id);
      expect(id, greaterThanOrEqualTo(90000000));
      expect(id, lessThan(100000000));

      final bill = BillEntity(
        id: 'tab-uuid-1',
        title: 'Rent',
        amount: 1,
        currency: 'OMR',
        category: BillCategory.rent,
        dueDate: DateTime(2026, 12, 1),
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );
      // Bills use 80000000–89999999; the daily ones are below 2000.
      expect(bill.notificationId, lessThan(90000000));
      expect(id, isNot(bill.notificationId));
    });

    test('the payload is the one a tap is routed by', () {
      expect(TabReminderService.payloadFor('t1'), 'pay_later:t1');
      expect(
        NotificationService.payLaterTabIdFrom(
          TabReminderService.payloadFor('t1'),
        ),
        't1',
      );
    });
  });

  group('rescheduleAll', () {
    test('schedules every tab that needs one and leaves the rest', () async {
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1'))
        ..addTab(monthlyTab('t2', reminder: false))
        ..addPurchase('t2', payLaterExpense('e2'))
        ..addTab(monthlyTab('t3', name: 'Corner shop', offset: 0))
        ..addPurchase('t3', payLaterExpense('e3'));

      await service.rescheduleAll();

      expect(plugin.pending.keys.toSet(), {idOf('t1'), idOf('t3')});
      expect(plugin.pending[idOf('t3')]!.body, 'Corner shop: settle-up day');
      // Nothing was pending for t2, so nothing to cancel.
      expect(plugin.cancelled, isEmpty);
    });

    test('a reminder already shown is not taken down by a later '
        're-schedule', () async {
      repo
        ..addTab(monthlyTab('t1', offset: 0))
        ..addPurchase('t1', payLaterExpense('e1'));
      now = DateTime(2026, 11, 10, 10);

      await service.rescheduleAll();

      // Not pending (it fired at 09:00); a cancel would remove it from the
      // shade.
      expect(plugin.cancelled, isEmpty);
    });

    test('cancels the pending reminder of a deleted tab', () async {
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1'));
      await service.rescheduleAll();
      repo.tabs.remove('t1');
      repo.purchases.remove('t1');

      await service.rescheduleAll();

      expect(plugin.pending, isEmpty);
      expect(plugin.cancelled, [idOf('t1')]);
    });

    test('leaves other notifications alone', () async {
      plugin.pending[NotificationService.morningReminderId] = _Scheduled(
        NotificationService.morningReminderId,
        'Morning',
        'x',
        tz.TZDateTime.now(tz.UTC),
        null,
        AndroidScheduleMode.inexactAllowWhileIdle,
      );

      await service.rescheduleAll();

      expect(
        plugin.pending.keys,
        contains(NotificationService.morningReminderId),
      );
      expect(plugin.cancelled, isEmpty);
    });

    test('when the pending list cannot be read it still cancels a tab that '
        'no longer needs one', () async {
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1'));
      await service.rescheduleAll();
      repo.purchases.remove('t1');
      plugin.pendingUnreadable = true;

      await service.rescheduleAll();

      expect(plugin.pending, isEmpty);
    });

    test(
      'a read failure is logged, never thrown, and keeps the schedule',
      () async {
        repo
          ..addTab(monthlyTab('t1'))
          ..addPurchase('t1', payLaterExpense('e1'));
        await service.rescheduleAll();
        repo.tabsError = Exception('disk I/O');

        await expectLater(service.rescheduleAll(), completes);
        expect(plugin.pending.keys, [idOf('t1')]);

        repo.readError = Exception('disk I/O');
        await expectLater(service.sync('t1'), completes);
        expect(plugin.pending.keys, [idOf('t1')]);
      },
    );

    test('never runs twice at once, and calls made while one runs share '
        'one follow-up run', () async {
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1'));
      repo.gate = Completer<void>();

      final first = service.rescheduleAll();
      await pumpEventQueue();
      final second = service.rescheduleAll();
      final third = service.rescheduleAll();
      repo.gate!.complete();
      await Future.wait([first, second, third]);

      expect(repo.maxInFlight, 1);
      // The first, then one shared run for the two that waited.
      expect(repo.getTabsCalls, 2);
    });

    test('does not initialise the plugin (that would drop the tap '
        'handler NotificationService registered)', () async {
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1'));

      await service.rescheduleAll();
      await service.sync('t1');

      expect(plugin.initializeCalls, 0);
      expect(plugin.pending, isNotEmpty);
    });
  });

  group('triggers', () {
    test('bus notify triggers one coalesced reschedule', () async {
      final payLater = RefreshBus('payLater');
      final day = RefreshBus('day');
      service.dispose();
      service = build(
        debounce: const Duration(milliseconds: 20),
        triggers: [payLater, day],
      );
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1'));

      service.start();
      payLater.notifyChanged();
      payLater.notifyChanged();
      day.notifyChanged();
      payLater.notifyChanged();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(repo.getTabsCalls, 1);
      expect(plugin.pending.keys, [idOf('t1')]);

      day.notifyChanged();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repo.getTabsCalls, 2);
    });

    test('start runs once at launch, and twice is still one '
        'subscription', () async {
      final payLater = RefreshBus('payLater');
      service.dispose();
      service = build(
        debounce: const Duration(milliseconds: 20),
        triggers: [payLater],
      );

      service.start();
      service.start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repo.getTabsCalls, 1);

      payLater.notifyChanged();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repo.getTabsCalls, 2);
    });

    test('after dispose a change does nothing', () async {
      final payLater = RefreshBus('payLater');
      service.dispose();
      service = build(
        debounce: const Duration(milliseconds: 20),
        triggers: [payLater],
      );
      service.start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final calls = repo.getTabsCalls;

      service.dispose();
      payLater.notifyChanged();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(repo.getTabsCalls, calls);
    });

    test('listens to the app-wide pay later and day buses by default', () {
      expect(TabReminderService.defaultTriggers, [
        RefreshBuses.payLater,
        RefreshBuses.day,
      ]);
    });
  });

  group('a reminder never records a payment', () {
    test('scheduling, syncing and firing triggers write nothing', () async {
      final payLater = RefreshBus('payLater');
      service.dispose();
      service = build(triggers: [payLater]);
      repo
        ..addTab(monthlyTab('t1', offset: 0))
        ..addPurchase('t1', payLaterExpense('e1', amount: 5));
      final tabsBefore = Map.of(repo.tabs);

      service.start();
      await service.rescheduleAll();
      await service.sync('t1');
      // The settle-up day itself, before and after the reminder fires.
      now = DateTime(2026, 11, 10, 8);
      await service.sync('t1');
      now = DateTime(2026, 11, 10, 9, 30);
      payLater.notifyChanged();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await service.rescheduleAll();

      expect(repo.createdPaymentIds, isEmpty);
      expect(repo.payments, isEmpty);
      expect(repo.allocations, isEmpty);
      expect(repo.tabs, tabsBefore);
      expect((await ledgerOf('t1')).owed, 5);
    });

    test('the service reaches no write use case or repository', () {
      final source = File(
        'lib/features/pay_later/data/services/tab_reminder_service.dart',
      ).readAsStringSync();
      final imports = RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!).toList();

      for (final forbidden in [
        'tab_payment_usecase',
        'tab_purchase_usecase',
        'manage_tab_usecase',
        'reconcile_tab_usecase',
        'pay_later_repository',
        'pay_later_local_datasource',
      ]) {
        expect(
          imports.where((i) => i.contains(forbidden)),
          isEmpty,
          reason: 'a reminder must never record a payment ($forbidden)',
        );
      }
    });
  });

  group('one pending reminder per tab, no catch-up', () {
    // Rule: one pending reminder per tab at 09:00 on (settle-up day −
    // offset); once that moment has passed, the following settle-up gets
    // it. Nothing records that one already went off.

    /// The one pending reminder of [tabId] as (year, month, day, hour).
    (int, int, int, int) atOf(String tabId) {
      final at = plugin.pending[idOf(tabId)]!.at;
      return (at.year, at.month, at.day, at.hour);
    }

    /// The platform drops a reminder from the pending list once it fires.
    void fire(String tabId) => plugin.pending.remove(idOf(tabId));

    late ManageTabUseCase manage;
    setUp(() => manage = ManageTabUseCase(repository: repo, clock: clock));

    Future<void> edit(PayLaterTab Function(PayLaterTab tab) change) async {
      final result = await manage.update(change(repo.tabs['t1']!));
      expect(result, isA<PayLaterSuccess<PayLaterTab>>());
      await service.rescheduleAll();
    }

    test('a first purchase after the reminder moment gets the following '
        'settle-up, never a late one', () async {
      // Settle-up 10 Nov, offset 2: the moment is 8 Nov 09:00.
      repo.addTab(monthlyTab('t1', offset: 2));
      for (final (moment, expected) in [
        (DateTime(2026, 11, 8, 8, 59), (2026, 11, 8, 9)),
        (DateTime(2026, 11, 8, 9, 0, 1), (2026, 12, 8, 9)),
        (DateTime(2026, 11, 8, 13), (2026, 12, 8, 9)),
        (DateTime(2026, 11, 9, 12), (2026, 12, 8, 9)),
        (DateTime(2026, 11, 10, 8), (2026, 12, 8, 9)),
        (DateTime(2026, 11, 10, 20), (2026, 12, 8, 9)),
        (DateTime(2026, 11, 11, 7), (2026, 12, 8, 9)),
      ]) {
        plugin.pending.clear();
        repo.purchases.clear();
        now = moment;
        repo.addPurchase(
          't1',
          payLaterExpense('e1').copyWith(date: moment.dateOnly, time: moment),
        );

        await service.rescheduleAll();

        expect(plugin.pending.keys, [idOf('t1')], reason: '$moment');
        expect(atOf('t1'), expected, reason: '$moment');
        expect(
          plugin.pending[idOf('t1')]!.body,
          'Campus cafeteria: settle-up in 2 days',
        );
      }
    });

    test('several purchases on one tab: one pending reminder under one id, '
        'replaced and never duplicated', () async {
      repo.addTab(monthlyTab('t1', offset: 2));
      for (var i = 1; i <= 3; i++) {
        repo.addPurchase('t1', payLaterExpense('e$i', amount: i.toDouble()));
        await service.rescheduleAll();
        await service.sync('t1');
      }

      expect(plugin.pending.keys, [idOf('t1')]);
      expect(plugin.scheduleCalls, 6, reason: 'each run replaces it by id');
      expect(plugin.cancelled, isEmpty);
      expect(atOf('t1'), (2026, 11, 8, 9));

      // It fires on 8 Nov; a purchase that afternoon: the next one only.
      fire('t1');
      now = DateTime(2026, 11, 8, 15);
      repo.addPurchase('t1', payLaterExpense('e4'));
      await service.rescheduleAll();
      expect(plugin.pending.keys, [idOf('t1')]);
      expect(atOf('t1'), (2026, 12, 8, 9));
    });

    test('editing the offset moves the one reminder', () async {
      repo
        ..addTab(monthlyTab('t1', offset: 2))
        ..addPurchase('t1', payLaterExpense('e1'));
      await service.rescheduleAll();
      expect(atOf('t1'), (2026, 11, 8, 9));

      await edit((t) => t.copyWith(reminderOffsetDays: 5));
      expect(atOf('t1'), (2026, 11, 5, 9));
      expect(
        plugin.pending[idOf('t1')]!.body,
        'Campus cafeteria: settle-up in 5 days',
      );

      await edit((t) => t.copyWith(reminderOffsetDays: 0));
      expect(atOf('t1'), (2026, 11, 10, 9));
      expect(
        plugin.pending[idOf('t1')]!.body,
        'Campus cafeteria: settle-up day',
      );

      // 4 Nov 10:00: offset 7 lands on 3 Nov (passed), offset 6 on 4 Nov
      // 09:00 (passed): both go to the December settle-up.
      now = DateTime(2026, 11, 4, 10);
      await edit((t) => t.copyWith(reminderOffsetDays: 7));
      expect(atOf('t1'), (2026, 12, 3, 9));
      await edit((t) => t.copyWith(reminderOffsetDays: 6));
      expect(atOf('t1'), (2026, 12, 4, 9));
      // Offset 5 lands on 5 Nov 09:00, still ahead.
      await edit((t) => t.copyWith(reminderOffsetDays: 5));
      expect(atOf('t1'), (2026, 11, 5, 9));

      expect(plugin.pending.keys, [idOf('t1')]);
      expect(plugin.cancelled, isEmpty);
    });

    test('changing the settle-up rhythm moves or cancels the one '
        'reminder', () async {
      repo
        ..addTab(monthlyTab('t1', offset: 2))
        ..addPurchase('t1', payLaterExpense('e1'));
      await service.rescheduleAll();
      expect(atOf('t1'), (2026, 11, 8, 9));

      // Weekly from 26 Oct: 2 Nov (today) and 9 Nov. 2 Nov − 2 has passed,
      // so 9 Nov − 2.
      await edit(
        (t) => t.copyWith(
          rhythm: EveryDays(days: 7, anchor: DateTime(2026, 10, 26)),
        ),
      );
      expect(atOf('t1'), (2026, 11, 7, 9));

      await edit(
        (t) => t.copyWith(
          rhythm: ManualDate(nextSettleDate: DateTime(2026, 11, 20)),
        ),
      );
      expect(atOf('t1'), (2026, 11, 18, 9));

      // Day 31 clamps to 30 Nov.
      await edit((t) => t.copyWith(rhythm: const MonthlyDay(day: 31)));
      expect(atOf('t1'), (2026, 11, 28, 9));

      await edit((t) => t.copyWith(rhythm: const OnDemand()));
      expect(plugin.pending, isEmpty);
      expect(plugin.cancelled, [idOf('t1')]);

      await edit((t) => t.copyWith(rhythm: const MonthlyDay(day: 10)));
      expect(plugin.pending.keys, [idOf('t1')]);
      expect(atOf('t1'), (2026, 11, 8, 9));
    });

    test('a restart re-schedules the same one reminder, and after one '
        'went off only the following one', () async {
      repo
        ..addTab(monthlyTab('t1', offset: 2))
        ..addPurchase('t1', payLaterExpense('e1'));
      await service.rescheduleAll();

      Future<void> restart() async {
        service.dispose();
        service = build();
        await service.rescheduleAll();
      }

      // The platform keeps what is pending across a restart.
      await restart();
      expect(plugin.pending.keys, [idOf('t1')]);
      expect(atOf('t1'), (2026, 11, 8, 9));

      // NotificationService.scheduleAll clears everything first, then
      // puts the tab reminders back with rescheduleAll.
      plugin.pending.clear();
      await restart();
      expect(plugin.pending.keys, [idOf('t1')]);
      expect(atOf('t1'), (2026, 11, 8, 9));

      // It went off on 8 Nov while the app was closed; opened on 9 Nov.
      fire('t1');
      now = DateTime(2026, 11, 9, 7);
      await restart();
      expect(plugin.pending.keys, [idOf('t1')]);
      expect(atOf('t1'), (2026, 12, 8, 9));

      // Nothing pending and opened at 09:01 on the reminder day: no
      // catch-up for today, the following settle-up instead.
      plugin.pending.clear();
      now = DateTime(2026, 12, 8, 9, 1);
      await restart();
      expect(plugin.pending.keys, [idOf('t1')]);
      expect(atOf('t1'), (2027, 1, 8, 9));
    });

    test('archiving a tab cancels its pending reminder, also when it still '
        'owes', () async {
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1'));
      await service.rescheduleAll();
      expect(plugin.pending.keys, [idOf('t1')]);

      // An archived tab can owe again when a payment is edited.
      repo.tabs['t1'] = repo.tabs['t1']!.copyWith(isArchived: true);
      await service.rescheduleAll();
      expect(plugin.pending, isEmpty);
      expect(plugin.cancelled, [idOf('t1')]);

      repo.tabs['t1'] = repo.tabs['t1']!.copyWith(isArchived: false);
      await service.sync('t1');
      expect(plugin.pending.keys, [idOf('t1')]);
      repo.tabs['t1'] = repo.tabs['t1']!.copyWith(isArchived: true);
      await service.sync('t1');
      expect(plugin.pending, isEmpty);
    });

    test('a tab in credit owes nothing: its reminder is cancelled', () async {
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1', amount: 5));
      await service.rescheduleAll();
      expect(plugin.pending.keys, [idOf('t1')]);

      // Paid in full, then the purchase is lowered: the freed money is
      // credit (a payment above what is owed is refused).
      final paid = await TabPaymentUseCase(
        repository: repo,
        reconcileTab: ReconcileTabUseCase(repository: repo),
        clock: clock,
      ).record(paymentId: 'p1', tabId: 't1', amount: 5, paidDate: now);
      expect(paid, isA<PayLaterSuccess>());
      repo.purchases['t1'] = [payLaterExpense('e1', amount: 3)];
      await ReconcileTabUseCase(repository: repo)('t1');
      final ledger = await ledgerOf('t1');
      expect((ledger.owed, ledger.credit), (0, 2));

      await service.rescheduleAll();
      expect(plugin.pending, isEmpty);
      expect(plugin.cancelled, [idOf('t1')]);
    });

    test('pick a date with nothing set: no reminder', () async {
      repo
        ..addTab(
          payLaterTab(
            't1',
            rhythm: const ManualDate(),
          ).copyWith(reminderEnabled: true, reminderOffsetDays: 0),
        )
        ..addPurchase('t1', payLaterExpense('e1'));

      await service.rescheduleAll();
      await service.sync('t1');

      expect(plugin.pending, isEmpty);
    });

    test(
      'turning the reminder off cancels it; on again schedules it',
      () async {
        repo
          ..addTab(monthlyTab('t1'))
          ..addPurchase('t1', payLaterExpense('e1'));
        await service.rescheduleAll();

        await edit((t) => t.copyWith(reminderEnabled: false));
        expect(plugin.pending, isEmpty);
        expect(plugin.cancelled, [idOf('t1')]);

        await edit((t) => t.copyWith(reminderEnabled: true));
        expect(plugin.pending.keys, [idOf('t1')]);
        expect(atOf('t1'), (2026, 11, 8, 9));

        // The single-tab path too.
        repo.tabs['t1'] = repo.tabs['t1']!.copyWith(reminderEnabled: false);
        await service.sync('t1');
        expect(plugin.pending, isEmpty);
      },
    );

    test('syncing a deleted tab cancels its pending reminder', () async {
      repo
        ..addTab(monthlyTab('t1'))
        ..addPurchase('t1', payLaterExpense('e1'));
      await service.sync('t1');
      expect(plugin.pending.keys, [idOf('t1')]);
      repo.tabs.remove('t1');
      repo.purchases.remove('t1');

      await service.sync('t1');

      expect(plugin.pending, isEmpty);
      expect(plugin.cancelled, [idOf('t1')]);
    });

    test('a picked date in the past: no reminder until a new date is '
        'set', () async {
      repo
        ..addTab(
          payLaterTab(
            't1',
            rhythm: ManualDate(nextSettleDate: DateTime(2026, 11, 20)),
          ).copyWith(reminderEnabled: true, reminderOffsetDays: 2),
        )
        ..addPurchase('t1', payLaterExpense('e1'));
      await service.rescheduleAll();
      expect(atOf('t1'), (2026, 11, 18, 9));

      // An edit may move the date into the past (only create refuses it).
      await edit(
        (t) => t.copyWith(
          rhythm: ManualDate(nextSettleDate: DateTime(2026, 10, 30)),
        ),
      );
      expect((await ledgerOf('t1')).needsSettleDate, isTrue);
      expect(plugin.pending, isEmpty);
      expect(plugin.cancelled, [idOf('t1')]);

      // A date passes on its own: 5 Nov, reminder 3 Nov, fired; on 6 Nov
      // nothing is scheduled and nothing advances.
      await edit(
        (t) => t.copyWith(
          rhythm: ManualDate(nextSettleDate: DateTime(2026, 11, 5)),
        ),
      );
      expect(atOf('t1'), (2026, 11, 3, 9));
      fire('t1');
      now = DateTime(2026, 11, 6, 10);
      await service.rescheduleAll();
      expect(plugin.pending, isEmpty);

      // The user sets the next date: the old one becomes the anchor and
      // the new date gets the reminder.
      await edit(
        (t) => t.copyWith(
          rhythm: ManualDate(nextSettleDate: DateTime(2026, 11, 25)),
        ),
      );
      expect(
        repo.tabs['t1']!.rhythm,
        ManualDate(
          nextSettleDate: DateTime(2026, 11, 25),
          anchor: DateTime(2026, 11, 5),
        ),
      );
      expect(plugin.pending.keys, [idOf('t1')]);
      expect(atOf('t1'), (2026, 11, 23, 9));
    });
  });
}
