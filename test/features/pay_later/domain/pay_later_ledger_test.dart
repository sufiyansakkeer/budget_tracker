import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/money_math.dart';
import 'package:monivo/core/dates/calendar_dates.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/payment_allocation.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_ledger.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_ledger.dart';

PayLaterTab _tab({
  String currency = 'OMR',
  SettleRhythm rhythm = const OnDemand(),
}) => PayLaterTab(
  id: 'tab-1',
  name: 'Campus cafeteria',
  category: PayLaterTabCategory.foodDining,
  currency: currency,
  rhythm: rhythm,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

ExpenseEntity _purchase(
  String id,
  double amount,
  DateTime date, {
  DateTime? time,
  DateTime? createdAt,
}) => ExpenseEntity(
  id: id,
  budgetId: 'budget-1',
  amount: amount,
  categoryId: 'food',
  date: date,
  time: time ?? DateTime(date.year, date.month, date.day, 12),
  createdAt: createdAt ?? date,
  updatedAt: createdAt ?? date,
);

TabPayment _payment(
  String id,
  double amount,
  DateTime paidDate, {
  DateTime? createdAt,
}) => TabPayment(
  id: id,
  tabId: 'tab-1',
  amount: amount,
  paidDate: paidDate,
  createdAt: createdAt ?? paidDate,
  updatedAt: createdAt ?? paidDate,
);

PaymentAllocation _alloc(
  String paymentId,
  String expenseId,
  double amount, {
  bool isManual = false,
}) => PaymentAllocation(
  id: '$paymentId:$expenseId',
  paymentId: paymentId,
  expenseId: expenseId,
  amount: amount,
  isManual: isManual,
  createdAt: DateTime(2026, 11, 1),
);

void main() {
  final omr = MoneyMath.forCurrency('OMR');

  /// Money compared in units, never as doubles.
  void expectMoney(double actual, double expected, {String? reason}) =>
      expect(omr.toUnits(actual), omr.toUnits(expected), reason: reason);

  PurchaseLine line(TabLedger ledger, String expenseId) =>
      ledger.purchases.singleWhere((p) => p.expense.id == expenseId);

  test('owed is purchases minus allocations', () {
    final ledger = PayLaterLedger.build(
      tab: _tab(),
      purchases: [
        _purchase('e1', 3.5, DateTime(2026, 11, 1)),
        _purchase('e2', 2.25, DateTime(2026, 11, 2)),
        _purchase('e3', 0.1, DateTime(2026, 11, 3)),
      ],
      payments: [_payment('p1', 1.2, DateTime(2026, 11, 4))],
      allocations: [_alloc('p1', 'e1', 1.0), _alloc('p1', 'e2', 0.2)],
      today: DateTime(2026, 11, 5),
    );

    expectMoney(ledger.owed, 4.65);
    expectMoney(ledger.credit, 0);
    expectMoney(ledger.totalAdded, 5.85);
    expectMoney(ledger.totalPaid, 1.2);
    expectMoney(line(ledger, 'e1').paid, 1.0);
    expectMoney(line(ledger, 'e1').owes, 2.5);
    expectMoney(line(ledger, 'e2').owes, 2.05);
    expectMoney(line(ledger, 'e3').owes, 0.1);
  });

  test('lines and payments in a full tie are ordered by id (M4)', () {
    final day = DateTime(2026, 11, 1);
    final ledger = PayLaterLedger.build(
      tab: _tab(),
      purchases: [_purchase('b', 1, day), _purchase('a', 1, day)],
      payments: [_payment('q', 1, day), _payment('p', 1, day)],
      allocations: const [],
      today: DateTime(2026, 11, 5),
    );

    expect(ledger.purchases.map((l) => l.expense.id), ['a', 'b']);
    expect(ledger.payments.map((l) => l.payment.id), ['p', 'q']);
  });

  test('status unpaid/partlyPaid/paid', () {
    final ledger = PayLaterLedger.build(
      tab: _tab(),
      purchases: [
        _purchase('paid', 1.5, DateTime(2026, 11, 1)),
        _purchase('part', 2.0, DateTime(2026, 11, 2)),
        _purchase('none', 0.75, DateTime(2026, 11, 3)),
      ],
      payments: [_payment('p1', 2.0, DateTime(2026, 11, 4))],
      allocations: [_alloc('p1', 'paid', 1.5), _alloc('p1', 'part', 0.5)],
      today: DateTime(2026, 11, 5),
    );

    expect(line(ledger, 'paid').status, PurchaseStatus.paid);
    expect(line(ledger, 'part').status, PurchaseStatus.partlyPaid);
    expect(line(ledger, 'none').status, PurchaseStatus.unpaid);
    // Purchases are listed oldest first.
    expect(ledger.purchases.map((p) => p.expense.id), ['paid', 'part', 'none']);
  });

  test('overdue sums only periods whose settle-up is before today', () {
    final tab = _tab(
      rhythm: EveryDays(days: 14, anchor: DateTime(2026, 10, 1)),
    );
    final purchases = [
      // [1 Oct, 14 Oct], settle-up 15 Oct.
      _purchase('e1', 2.0, DateTime(2026, 10, 5)),
      _purchase('e2', 1.0, DateTime(2026, 10, 14)),
      // [15 Oct, 28 Oct], settle-up 29 Oct.
      _purchase('e3', 4.0, DateTime(2026, 10, 16)),
    ];
    final payments = [_payment('p1', 0.5, DateTime(2026, 10, 10))];
    final allocations = [_alloc('p1', 'e1', 0.5)];

    TabLedger on(DateTime today) => PayLaterLedger.build(
      tab: tab,
      purchases: purchases,
      payments: payments,
      allocations: allocations,
      today: today,
    );

    final late = on(DateTime(2026, 10, 20));
    expectMoney(late.overdue, 2.5);
    expectMoney(late.owed, 6.5);
    expect(late.periods.map((p) => p.overdue), [true, false]);
    expect(late.nextSettleUp, DateTime(2026, 10, 29));
    expect(late.needsSettleDate, isFalse);

    // On the settle-up day itself nothing is overdue yet.
    final dueToday = on(DateTime(2026, 10, 15, 9));
    expectMoney(dueToday.overdue, 0);
    expect(dueToday.periods.map((p) => p.overdue), [false, false]);
    expect(dueToday.nextSettleUp, DateTime(2026, 10, 15), reason: 'due today');

    // A paid-up period is not overdue.
    final paidUp = PayLaterLedger.build(
      tab: tab,
      purchases: purchases,
      payments: [_payment('p1', 3.0, DateTime(2026, 10, 14))],
      allocations: [_alloc('p1', 'e1', 2.0), _alloc('p1', 'e2', 1.0)],
      today: DateTime(2026, 10, 20),
    );
    expectMoney(paidUp.overdue, 0);
    expect(paidUp.periods.first.overdue, isFalse);

    // On demand is never overdue.
    final onDemand = PayLaterLedger.build(
      tab: _tab(),
      purchases: purchases,
      payments: payments,
      allocations: allocations,
      today: DateTime(2027, 1, 1),
    );
    expectMoney(onDemand.overdue, 0);
    expect(onDemand.periods, isEmpty);
    expect(onDemand.nextSettleUp, isNull);
    expect(onDemand.purchases.every((p) => p.period == null), isTrue);
  });

  test('manual date: passed date with none set needs a settle date; '
      'the open period is never overdue', () {
    final tab = _tab(
      rhythm: ManualDate(
        anchor: DateTime(2026, 10, 1),
        nextSettleDate: DateTime(2026, 10, 15),
      ),
    );
    final ledger = PayLaterLedger.build(
      tab: tab,
      purchases: [
        _purchase('earlier', 1.0, DateTime(2026, 9, 20)),
        _purchase('current', 2.0, DateTime(2026, 10, 3)),
        _purchase('open', 4.0, DateTime(2026, 10, 18)),
      ],
      payments: const [],
      allocations: const [],
      today: DateTime(2026, 10, 20),
    );

    expect(ledger.needsSettleDate, isTrue);
    expect(ledger.nextSettleUp, isNull);
    // Earlier (settle-up 1 Oct) and current (settle-up 15 Oct) are overdue.
    expectMoney(ledger.overdue, 3.0);
    expect(ledger.periods.map((p) => p.overdue), [true, true, false]);
    expect(ledger.periods.last.period.isOpen, isTrue);

    final beforeDate = PayLaterLedger.build(
      tab: tab,
      purchases: const [],
      payments: const [],
      allocations: const [],
      today: DateTime(2026, 10, 15),
    );
    expect(beforeDate.needsSettleDate, isFalse);
    expect(beforeDate.nextSettleUp, DateTime(2026, 10, 15));
    expect(
      PayLaterLedger.build(
        tab: _tab(),
        purchases: const [],
        payments: const [],
        allocations: const [],
        today: DateTime(2026, 10, 15),
      ).needsSettleDate,
      isFalse,
      reason: 'on demand never asks for a date',
    );
  });

  test('credit equals unapplied payment money', () {
    final ledger = PayLaterLedger.build(
      tab: _tab(),
      purchases: [_purchase('e1', 3.0, DateTime(2026, 11, 1))],
      payments: [
        _payment('p1', 2.0, DateTime(2026, 11, 2)),
        _payment('p2', 3.25, DateTime(2026, 11, 3)),
      ],
      allocations: [_alloc('p1', 'e1', 2.0), _alloc('p2', 'e1', 1.0)],
      today: DateTime(2026, 11, 5),
    );

    expectMoney(ledger.owed, 0);
    expectMoney(ledger.credit, 2.25);
    expectMoney(ledger.payments[0].unapplied, 0);
    expectMoney(ledger.payments[1].unapplied, 2.25);
    expect(ledger.payments[1].allocations, [_alloc('p2', 'e1', 1.0)]);
  });

  test('balanceAfter per payment in date order', () {
    final ledger = PayLaterLedger.build(
      tab: _tab(),
      purchases: [
        _purchase('e1', 3.0, DateTime(2026, 11, 1)),
        _purchase('e2', 2.0, DateTime(2026, 11, 5)),
      ],
      // Given out of order; same-day payments order by createdAt.
      payments: [
        _payment('late', 1.0, DateTime(2026, 11, 6)),
        _payment(
          'b',
          0.5,
          DateTime(2026, 11, 3),
          createdAt: DateTime(2026, 11, 3, 18),
        ),
        _payment(
          'a',
          1.5,
          DateTime(2026, 11, 3),
          createdAt: DateTime(2026, 11, 3, 9),
        ),
      ],
      allocations: [
        _alloc('a', 'e1', 1.5),
        _alloc('b', 'e1', 0.5),
        _alloc('late', 'e1', 1.0),
      ],
      today: DateTime(2026, 11, 7),
    );

    expect(ledger.payments.map((p) => p.payment.id), ['a', 'b', 'late']);
    expectMoney(ledger.payments[0].balanceAfter, 1.5);
    expectMoney(ledger.payments[1].balanceAfter, 1.0);
    // e2 (5 Nov) is before the 6 Nov payment: 5.0 − 3.0.
    expectMoney(ledger.payments[2].balanceAfter, 2.0);
  });

  test('back-dated payment recorded after later purchases shows the balance '
      'as of its date', () {
    // Recorded on 12 Nov but dated 2 Nov; FIFO put its money on both
    // purchases, one of them dated after 2 Nov.
    final ledger = PayLaterLedger.build(
      tab: _tab(),
      purchases: [
        _purchase('e1', 4.0, DateTime(2026, 11, 1)),
        _purchase('e2', 3.0, DateTime(2026, 11, 10)),
      ],
      payments: [
        _payment(
          'p1',
          5.0,
          DateTime(2026, 11, 2),
          createdAt: DateTime(2026, 11, 12, 20),
        ),
      ],
      allocations: [_alloc('p1', 'e1', 4.0), _alloc('p1', 'e2', 1.0)],
      today: DateTime(2026, 11, 12),
    );

    // As of 2 Nov only e1 existed: 4.0 − 5.0 → in credit 1.0 then.
    expectMoney(ledger.payments.single.balanceAfter, -1.0);
    // Today the tab owes 2.0.
    expectMoney(ledger.owed, 2.0);
    expectMoney(ledger.credit, 0);
  });

  test('last payment balance equals header when nothing is dated after it', () {
    final ledger = PayLaterLedger.build(
      tab: _tab(),
      purchases: [
        _purchase('e1', 1.25, DateTime(2026, 11, 1)),
        _purchase('e2', 2.5, DateTime(2026, 11, 2)),
        // Same day as the payment, later in the day: counts as before it.
        _purchase(
          'e3',
          0.75,
          DateTime(2026, 11, 3),
          time: DateTime(2026, 11, 3, 23, 30),
        ),
      ],
      payments: [
        _payment('p1', 1.0, DateTime(2026, 11, 1)),
        _payment('p2', 2.0, DateTime(2026, 11, 3, 8)),
      ],
      allocations: [
        _alloc('p1', 'e1', 1.0),
        _alloc('p2', 'e1', 0.25),
        _alloc('p2', 'e2', 1.75),
      ],
      today: DateTime(2026, 11, 4),
    );

    final header = omr.toUnits(ledger.owed) - omr.toUnits(ledger.credit);
    expect(omr.toUnits(ledger.payments.last.balanceAfter), header);
    expectMoney(ledger.payments.last.balanceAfter, 1.5);
    expectMoney(ledger.payments.first.balanceAfter, 0.25);
  });

  test('totals per period', () {
    final ledger = PayLaterLedger.build(
      tab: _tab(rhythm: const MonthlyDay(day: 1)),
      purchases: [
        _purchase('nov', 3.0, DateTime(2026, 11, 2)),
        _purchase('oct1', 1.5, DateTime(2026, 10, 3)),
        _purchase('oct2', 2.5, DateTime(2026, 10, 30)),
      ],
      payments: [_payment('p1', 3.0, DateTime(2026, 11, 1))],
      allocations: [_alloc('p1', 'oct1', 1.5), _alloc('p1', 'oct2', 1.5)],
      today: DateTime(2026, 11, 5),
    );

    expect(ledger.periods, hasLength(2));
    final oct = ledger.periods[0];
    final nov = ledger.periods[1];

    expect(oct.period.start, DateTime(2026, 10, 1));
    expect(oct.period.settleUp, DateTime(2026, 11, 1));
    expect(oct.purchases.map((p) => p.expense.id), ['oct1', 'oct2']);
    expectMoney(oct.total, 4.0);
    expectMoney(oct.paid, 3.0);
    expectMoney(oct.owes, 1.0);
    expect(oct.overdue, isTrue);

    expect(nov.period.start, DateTime(2026, 11, 1));
    expect(nov.purchases.map((p) => p.expense.id), ['nov']);
    expectMoney(nov.total, 3.0);
    expectMoney(nov.paid, 0);
    expectMoney(nov.owes, 3.0);
    expect(nov.overdue, isFalse);

    expectMoney(ledger.overdue, 1.0);
    expect(ledger.nextSettleUp, DateTime(2026, 12, 1));
    expect(line(ledger, 'oct2').period, oct.period);
  });

  test('allocations to purchases or payments not given are ignored on both '
      'sides', () {
    final ledger = PayLaterLedger.build(
      tab: _tab(),
      purchases: [_purchase('e1', 2.0, DateTime(2026, 11, 1))],
      payments: [_payment('p1', 1.0, DateTime(2026, 11, 2))],
      allocations: [
        _alloc('p1', 'gone', 0.4),
        _alloc('p1', 'e1', 0.6),
        _alloc('gone', 'e1', 1.0),
      ],
      today: DateTime(2026, 11, 3),
    );

    expectMoney(ledger.owed, 1.4);
    expectMoney(ledger.credit, 0.4);
    expect(ledger.payments.single.allocations, [_alloc('p1', 'e1', 0.6)]);
  });

  test('balanceAfter equals purchases to date minus payments to date', () {
    final random = Random(42);
    const currencies = ['OMR', 'USD', 'JPY'];
    final base = DateTime(2026, 10, 20);

    for (var scenario = 0; scenario < 200; scenario++) {
      final currency = currencies[random.nextInt(currencies.length)];
      final money = MoneyMath.forCurrency(currency);
      final tab = _tab(currency: currency);
      final purchaseCount = 1 + random.nextInt(8);
      final paymentCount = random.nextInt(7);

      final purchases = [
        for (var i = 0; i < purchaseCount; i++)
          _purchase(
            'e$i',
            money.toAmount(1 + random.nextInt(50000)),
            // 20 Oct – 18 Nov, across the 1 Nov DST change.
            base.addDays(random.nextInt(30)),
            time: DateTime(2026, 1, 1, random.nextInt(24), random.nextInt(60)),
            createdAt: base.add(Duration(minutes: random.nextInt(100000))),
          ),
      ];
      final payments = [
        for (var i = 0; i < paymentCount; i++)
          _payment(
            'p$i',
            money.toAmount(1 + random.nextInt(40000)),
            base.addDays(random.nextInt(30)),
            createdAt: base.add(Duration(minutes: random.nextInt(100000))),
          ),
      ];
      final allocations = _validAllocations(
        money,
        purchases,
        payments,
        shuffle: random.nextBool() ? random : null,
      );

      final ledger = PayLaterLedger.build(
        tab: tab,
        purchases: purchases,
        payments: payments,
        allocations: allocations,
        today: DateTime(2026, 11, 20),
      );
      final ordered = ledger.payments.map((l) => l.payment).toList();

      for (var k = 0; k < ordered.length; k++) {
        final day = DateTime(
          ordered[k].paidDate.year,
          ordered[k].paidDate.month,
          ordered[k].paidDate.day,
        );
        final paymentsToDate = ordered.sublist(0, k + 1);
        final paymentIds = {for (final p in paymentsToDate) p.id};
        final purchasesToDate = [
          for (final e in purchases)
            if (!DateTime(e.date.year, e.date.month, e.date.day).isAfter(day))
              e,
        ];
        final purchaseIds = {for (final e in purchasesToDate) e.id};
        final asOf = PayLaterLedger.build(
          tab: tab,
          purchases: purchasesToDate,
          payments: paymentsToDate,
          allocations: [
            for (final a in allocations)
              if (paymentIds.contains(a.paymentId) &&
                  purchaseIds.contains(a.expenseId))
                a,
          ],
          today: DateTime(2026, 11, 20),
        );

        expect(
          money.toUnits(asOf.owed) - money.toUnits(asOf.credit),
          money.toUnits(ledger.payments[k].balanceAfter),
          reason: 'scenario $scenario ($currency), payment ${k + 1}',
        );
      }

      if (ordered.isNotEmpty) {
        final lastDay = ordered.last.paidDate;
        final nothingAfter = purchases.every(
          (e) => !DateTime(
            e.date.year,
            e.date.month,
            e.date.day,
          ).isAfter(DateTime(lastDay.year, lastDay.month, lastDay.day)),
        );
        if (nothingAfter) {
          expect(
            money.toUnits(ledger.payments.last.balanceAfter),
            money.toUnits(ledger.owed) - money.toUnits(ledger.credit),
            reason: 'scenario $scenario: last balance equals header',
          );
        }
      }
    }
  });

  group('overdue starts the day after the settle-up day, for every rhythm', () {
    // For each rhythm: a settle-up day S, the settle-up after it (null for
    // a picked date: nothing advances), a purchase on S − 1 (the last day
    // of the period settling on S) and one on S (the first day of the next
    // period).
    final cases = <String, (SettleRhythm, DateTime, DateTime?)>{
      'every 7 days': (
        EveryDays(days: 7, anchor: DateTime(2026, 10, 26)),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 9),
      ),
      'monthly day 31, February': (
        const MonthlyDay(day: 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
      ),
      'monthly day 31, 30-day month': (
        const MonthlyDay(day: 31),
        DateTime(2027, 4, 30),
        DateTime(2027, 5, 31),
      ),
      'monthly day 29, February': (
        const MonthlyDay(day: 29),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 29),
      ),
      'monthly day 30, leap-year February': (
        const MonthlyDay(day: 30),
        DateTime(2028, 2, 29),
        DateTime(2028, 3, 30),
      ),
      'monthly day 1, year end': (
        const MonthlyDay(day: 1),
        DateTime(2027, 1, 1),
        DateTime(2027, 2, 1),
      ),
      'pick a date': (
        ManualDate(
          anchor: DateTime(2026, 11, 1),
          nextSettleDate: DateTime(2026, 11, 30),
        ),
        DateTime(2026, 11, 30),
        null,
      ),
    };

    for (final MapEntry(key: name, value: (rhythm, settleUp, following))
        in cases.entries) {
      test(name, () {
        TabLedger on(DateTime today) => PayLaterLedger.build(
          tab: _tab(rhythm: rhythm),
          purchases: [
            _purchase('last', 1.5, settleUp.addDays(-1)),
            _purchase('next', 2.0, settleUp),
          ],
          payments: const [],
          allocations: const [],
          today: today,
        );
        DateTime lateOn(DateTime day) =>
            DateTime(day.year, day.month, day.day, 23, 59);

        final dayBefore = settleUp.addDays(-1);
        for (final today in [dayBefore, lateOn(dayBefore)]) {
          final ledger = on(today);
          expectMoney(ledger.overdue, 0, reason: 'day before ($today)');
          expect(ledger.nextSettleUp, settleUp, reason: 'day before');
          expect(ledger.periods.any((p) => p.overdue), isFalse);
        }

        // The settle-up day itself: due today, nothing overdue yet.
        for (final today in [settleUp, lateOn(settleUp)]) {
          final ledger = on(today);
          expectMoney(ledger.overdue, 0, reason: 'settle-up day ($today)');
          expect(ledger.nextSettleUp, settleUp, reason: 'settle-up day');
          expect(ledger.asOf, settleUp);
          expect(ledger.periods.any((p) => p.overdue), isFalse);
          expect(line(ledger, 'last').period!.settleUp, settleUp);
        }

        // From the first moment of the day after: only the period that
        // settled on S is overdue; the purchase made on S is not.
        final dayAfter = on(settleUp.addDays(1));
        expectMoney(dayAfter.overdue, 1.5);
        expectMoney(dayAfter.owed, 3.5);
        expect(dayAfter.nextSettleUp, following);
        expect(dayAfter.needsSettleDate, following == null);
        final lastPeriod = dayAfter.periods.singleWhere(
          (p) => p.purchases.any((l) => l.expense.id == 'last'),
        );
        expect(lastPeriod.overdue, isTrue);
        final nextPeriod = dayAfter.periods.singleWhere(
          (p) => p.purchases.any((l) => l.expense.id == 'next'),
        );
        expect(nextPeriod.overdue, isFalse);
      });

      // Paid the period settling on S the day before, then bought on S:
      // nothing is due on S, so it isn't "settle up today".
      test('$name: nothing due on the settle-up day skips ahead', () {
        TabLedger on(DateTime today) => PayLaterLedger.build(
          tab: _tab(rhythm: rhythm),
          purchases: [
            _purchase('last', 1.5, settleUp.addDays(-1)),
            _purchase('next', 2.0, settleUp),
          ],
          payments: [_payment('p1', 1.5, settleUp.addDays(-1))],
          allocations: [_alloc('p1', 'last', 1.5)],
          today: today,
        );

        final ledger = on(settleUp);
        expectMoney(ledger.owed, 2.0);
        expectMoney(ledger.overdue, 0);
        expect(ledger.nextSettleUp, following, reason: 'nothing due on S');
        expect(ledger.needsSettleDate, following == null);
      });

      // Still owing on the period settling on S: S is "today".
      test('$name: something due on the settle-up day stays today', () {
        final ledger = PayLaterLedger.build(
          tab: _tab(rhythm: rhythm),
          purchases: [
            _purchase('last', 1.5, settleUp.addDays(-1)),
            _purchase('next', 2.0, settleUp),
          ],
          payments: [_payment('p1', 1.0, settleUp.addDays(-1))],
          allocations: [_alloc('p1', 'last', 1.0)],
          today: settleUp,
        );
        expect(ledger.nextSettleUp, settleUp);
      });
    }

    test('on demand: never overdue, no settle-up day', () {
      for (final today in [
        DateTime(2027, 2, 27),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 1),
        DateTime(2030, 1, 1),
      ]) {
        final ledger = PayLaterLedger.build(
          tab: _tab(),
          purchases: [_purchase('e1', 1.5, DateTime(2027, 2, 27))],
          payments: const [],
          allocations: const [],
          today: today,
        );
        expectMoney(ledger.overdue, 0);
        expect(ledger.nextSettleUp, isNull);
        expect(ledger.needsSettleDate, isFalse);
      }
    });
  });
}

/// Valid allocations: payments oldest first (paidDate, createdAt), each
/// spread over purchases in FIFO order (or a shuffled order), never above
/// what a purchase still owes or what a payment has left. Payments may be
/// larger than everything owed, leaving credit.
List<PaymentAllocation> _validAllocations(
  MoneyMath money,
  List<ExpenseEntity> purchases,
  List<TabPayment> payments, {
  Random? shuffle,
}) {
  final orderedPayments = [...payments]
    ..sort((a, b) {
      final byDate = DateTime(
        a.paidDate.year,
        a.paidDate.month,
        a.paidDate.day,
      ).compareTo(DateTime(b.paidDate.year, b.paidDate.month, b.paidDate.day));
      return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
    });
  final orderedPurchases = [...purchases]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.createdAt.compareTo(b.createdAt);
    });
  if (shuffle != null) orderedPurchases.shuffle(shuffle);

  final owes = {for (final e in purchases) e.id: money.toUnits(e.amount)};
  final result = <PaymentAllocation>[];
  for (final payment in orderedPayments) {
    var left = money.toUnits(payment.amount);
    for (final purchase in orderedPurchases) {
      if (left == 0) break;
      final take = min(left, owes[purchase.id]!);
      if (take == 0) continue;
      owes[purchase.id] = owes[purchase.id]! - take;
      left -= take;
      result.add(
        PaymentAllocation(
          id: '${payment.id}:${purchase.id}',
          paymentId: payment.id,
          expenseId: purchase.id,
          amount: money.toAmount(take),
          isManual: false,
          createdAt: payment.createdAt,
        ),
      );
    }
  }
  return result;
}
