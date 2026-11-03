import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/money_math.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/payment_allocation.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_ledger.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/services/fifo_order.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_allocator.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_ledger.dart';

final _now = DateTime(2026, 11, 2, 9);

PayLaterTab _tab(String currency) => PayLaterTab(
  id: 'tab-1',
  name: 'Campus cafeteria',
  category: PayLaterTabCategory.foodDining,
  currency: currency,
  rhythm: const OnDemand(),
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

/// An allocator with predictable ids (`new-1`, `new-2`, …) and clock.
PayLaterAllocator _allocator(String currency) {
  var next = 0;
  return PayLaterAllocator(
    currency: currency,
    newId: () => 'new-${++next}',
    clock: () => _now,
  );
}

/// [allocations] with [diff] applied, as the repository will write it.
List<PaymentAllocation> _apply(
  List<PaymentAllocation> allocations,
  AllocationDiff diff,
) => [
  for (final a in allocations)
    if (!diff.deletes.contains(a.id))
      diff.updates.containsKey(a.id)
          ? a.copyWith(amount: diff.updates[a.id])
          : a,
  ...diff.inserts,
];

void main() {
  /// The allocation set as `payment→purchase: units` (manual rows marked
  /// with `*`), so assertions compare integers, never doubles.
  Map<String, int> shape(MoneyMath money, List<PaymentAllocation> rows) => {
    for (final a in rows)
      '${a.paymentId}→${a.expenseId}${a.isManual ? '*' : ''}': money.toUnits(
        a.amount,
      ),
  };

  final omr = MoneyMath.forCurrency('OMR');

  /// Reconciles and returns the resulting allocation set.
  List<PaymentAllocation> reconciled(
    PayLaterAllocator allocator, {
    required List<ExpenseEntity> purchases,
    required List<TabPayment> payments,
    List<PaymentAllocation> allocations = const [],
  }) {
    final diff = allocator.reconcile(
      purchases: purchases,
      payments: payments,
      allocations: allocations,
    );
    return _apply(allocations, diff);
  }

  test('fifo pays oldest purchase first, ties by time then createdAt', () {
    final day = DateTime(2026, 11, 1);
    final purchases = [
      _purchase('nextDay', 1.0, DateTime(2026, 11, 2)),
      _purchase(
        'noonLater',
        1.0,
        day,
        time: DateTime(2026, 11, 1, 12),
        createdAt: DateTime(2026, 11, 1, 12, 30),
      ),
      _purchase(
        'noonEarlier',
        1.0,
        day,
        time: DateTime(2026, 11, 1, 12),
        createdAt: DateTime(2026, 11, 1, 12, 10),
      ),
      _purchase('morning', 1.0, day, time: DateTime(2026, 11, 1, 9)),
    ];
    final rows = reconciled(
      _allocator('OMR'),
      purchases: purchases,
      payments: [_payment('p1', 2.5, DateTime(2026, 11, 3))],
    );

    expect(shape(omr, rows), {
      'p1→morning': 1000,
      'p1→noonEarlier': 1000,
      'p1→noonLater': 500,
    });
    expect(rows.map((a) => a.id), ['new-1', 'new-2', 'new-3']);
    expect(rows.every((a) => a.createdAt == _now), isTrue);
  });

  test('a full tie (same day, time and created) is broken by id, whatever '
      'order the purchases come in (M4)', () {
    final day = DateTime(2026, 11, 1);
    ExpenseEntity tied(String id) =>
        _purchase(id, 1.0, day, time: DateTime(2026, 11, 1, 12));
    final payments = [_payment('p1', 1.0, DateTime(2026, 11, 3))];
    for (final order in [
      [tied('b'), tied('a')],
      [tied('a'), tied('b')],
    ]) {
      final rows = reconciled(
        _allocator('OMR'),
        purchases: order,
        payments: payments,
      );
      expect(shape(omr, rows), {'p1→a': 1000}, reason: '$order');
    }
    // Payments too: same paid day and created, the smaller id pays first.
    final purchases = [_purchase('e1', 1.0, day)];
    for (final order in [
      [_payment('q', 1.0, day), _payment('p', 1.0, day)],
      [_payment('p', 1.0, day), _payment('q', 1.0, day)],
    ]) {
      final rows = reconciled(
        _allocator('OMR'),
        purchases: purchases,
        payments: order,
      );
      expect(shape(omr, rows), {'p→e1': 1000});
    }
  });

  test('FifoOrder is the one order the ledger and allocator share', () {
    final day = DateTime(2026, 11, 1);
    final a = _purchase('a', 1.0, day);
    final b = _purchase('b', 1.0, day);
    expect(FifoOrder.purchases(a, b), lessThan(0));
    expect(FifoOrder.purchases(b, a), greaterThan(0));
    expect(FifoOrder.purchases(a, a), 0);
    final later = _purchase('0', 1.0, DateTime(2026, 11, 2));
    expect(FifoOrder.purchases(b, later), lessThan(0));
    expect(
      FifoOrder.payments(_payment('q', 1, day), _payment('p', 1, day)),
      greaterThan(0),
    );
  });

  test('partial payment leaves the remainder owing on the next purchase', () {
    final purchases = [
      _purchase('e1', 2.0, DateTime(2026, 11, 1)),
      _purchase('e2', 3.0, DateTime(2026, 11, 2)),
      _purchase('e3', 4.0, DateTime(2026, 11, 3)),
    ];
    final payments = [_payment('p1', 3.5, DateTime(2026, 11, 4))];
    final rows = reconciled(
      _allocator('OMR'),
      purchases: purchases,
      payments: payments,
    );

    expect(shape(omr, rows), {'p1→e1': 2000, 'p1→e2': 1500});
    final ledger = PayLaterLedger.build(
      tab: _tab('OMR'),
      purchases: purchases,
      payments: payments,
      allocations: rows,
      today: _now,
    );
    final e2 = ledger.purchases.singleWhere((l) => l.expense.id == 'e2');
    expect(omr.toUnits(e2.owes), 1500);
    expect(e2.status, PurchaseStatus.partlyPaid);
    expect(omr.toUnits(ledger.owed), 5500);
  });

  test('multiple payments continue where the last stopped', () {
    final purchases = [
      _purchase('e1', 2.0, DateTime(2026, 11, 1)),
      _purchase('e2', 3.0, DateTime(2026, 11, 2)),
      _purchase('e3', 4.0, DateTime(2026, 11, 3)),
    ];
    final first = [_alloc('p1', 'e1', 2.0), _alloc('p1', 'e2', 1.0)];
    final allocator = _allocator('OMR');
    final rows = reconciled(
      allocator,
      purchases: purchases,
      // p1 was applied earlier; p2 is new and picks up where p1 stopped.
      payments: [
        _payment('p1', 3.0, DateTime(2026, 11, 4)),
        _payment('p2', 3.0, DateTime(2026, 11, 5)),
      ],
      allocations: first,
    );

    expect(shape(omr, rows), {
      'p1→e1': 2000,
      'p1→e2': 1000,
      'p2→e2': 2000,
      'p2→e3': 1000,
    });
  });

  test('chosen purchases are paid first and marked manual; leftover goes '
      'fifo', () {
    final purchases = [
      _purchase('e1', 1.0, DateTime(2026, 11, 1)),
      _purchase('e2', 1.0, DateTime(2026, 11, 2)),
      _purchase('e3', 1.0, DateTime(2026, 11, 3)),
    ];
    final payment = _payment('p1', 2.5, DateTime(2026, 11, 4));
    final allocator = _allocator('OMR');

    final chosen = allocator.allocateChosen(
      payment: payment,
      purchases: purchases,
      existing: const [],
      chosenExpenseIds: {'e3', 'e2'},
    );
    // FIFO among the chosen ones, all manual, the leftover not applied yet.
    expect(chosen.map((a) => a.expenseId), ['e2', 'e3']);
    expect(chosen.every((a) => a.isManual), isTrue);
    expect(shape(omr, chosen), {'p1→e2*': 1000, 'p1→e3*': 1000});
    expect(chosen.map((a) => a.id), ['new-1', 'new-2']);
    expect(chosen.every((a) => a.createdAt == _now), isTrue);

    final rows = reconciled(
      allocator,
      purchases: purchases,
      payments: [payment],
      allocations: chosen,
    );
    expect(shape(omr, rows), {'p1→e2*': 1000, 'p1→e3*': 1000, 'p1→e1': 500});
  });

  test('allocation never exceeds what a purchase owes', () {
    final purchases = [
      _purchase('e1', 1.0, DateTime(2026, 11, 1)),
      _purchase('e2', 0.8, DateTime(2026, 11, 2)),
      _purchase('e3', 5.0, DateTime(2026, 11, 3)),
    ];
    final p0 = _payment('p0', 0.6, DateTime(2026, 11, 3));
    final p1 = _payment('p1', 2.0, DateTime(2026, 11, 4));
    final existing = [_alloc('p0', 'e1', 0.6)];
    final allocator = _allocator('OMR');

    // e1 owes 0.4 after p0; e2 owes 0.8. Chosen rows stop at each owes.
    final chosen = allocator.allocateChosen(
      payment: p1,
      purchases: purchases,
      existing: existing,
      chosenExpenseIds: {'e1', 'e2'},
    );
    expect(shape(omr, chosen), {'p1→e1*': 400, 'p1→e2*': 800});

    // A fully paid chosen purchase gets no row at all.
    final none = allocator.allocateChosen(
      payment: p1,
      purchases: purchases,
      existing: [...existing, ...chosen],
      chosenExpenseIds: {'e1', 'e2'},
    );
    expect(none, isEmpty);

    // Stored rows above a purchase's amount are trimmed back to it.
    final rows = reconciled(
      allocator,
      purchases: purchases,
      payments: [p0, p1],
      allocations: [
        _alloc('p0', 'e1', 0.6),
        _alloc('p1', 'e1', 1.0), // e1 would be paid 1.6 of 1.0
      ],
    );
    final paid = <String, int>{};
    for (final a in rows) {
      paid.update(
        a.expenseId,
        (v) => v + omr.toUnits(a.amount),
        ifAbsent: () => omr.toUnits(a.amount),
      );
    }
    for (final e in purchases) {
      expect(paid[e.id] ?? 0, lessThanOrEqualTo(omr.toUnits(e.amount)));
    }
    expect(shape(omr, rows), {
      'p0→e1': 600,
      'p1→e1': 400, // latest payment trimmed first
      'p1→e2': 800,
      'p1→e3': 800,
    });
  });

  test('payment amount reduced trims automatic before manual, newest '
      'purchase first', () {
    final purchases = [
      _purchase('e1', 1.0, DateTime(2026, 11, 1)),
      _purchase('e2', 1.0, DateTime(2026, 11, 2)),
      _purchase('e3', 1.0, DateTime(2026, 11, 3)),
    ];
    final allocations = [
      _alloc('p1', 'e1', 1.0),
      _alloc('p1', 'e2', 1.0),
      _alloc('p1', 'e3', 1.0, isManual: true),
    ];
    final allocator = _allocator('OMR');
    final diff = allocator.reconcile(
      purchases: purchases,
      // Was 3.000; edited down to 1.500.
      payments: [_payment('p1', 1.5, DateTime(2026, 11, 4))],
      allocations: allocations,
    );

    // e3 is the newest purchase but manual, so it is trimmed last; among
    // the automatic ones e2 (newer) goes before e1.
    expect(diff.deletes, {'p1:e2'});
    expect(diff.updates.keys, ['p1:e1']);
    expect(omr.toUnits(diff.updates['p1:e1']!), 500);
    expect(diff.inserts, isEmpty);
    expect(shape(omr, _apply(allocations, diff)), {
      'p1→e1': 500,
      'p1→e3*': 1000,
    });
  });

  test('purchase amount reduced frees money, which moves to the next unpaid '
      'purchase', () {
    final allocations = [_alloc('p1', 'e1', 4.0), _alloc('p2', 'e1', 6.0)];
    final payments = [
      _payment('p1', 4.0, DateTime(2026, 11, 3)),
      _payment('p2', 6.0, DateTime(2026, 11, 4)),
    ];
    final allocator = _allocator('OMR');

    // e1 edited from 10.000 down to 5.000; e2 still owes 3.000.
    final purchases = [
      _purchase('e1', 5.0, DateTime(2026, 11, 1)),
      _purchase('e2', 3.0, DateTime(2026, 11, 2)),
    ];
    final rows = reconciled(
      allocator,
      purchases: purchases,
      payments: payments,
      allocations: allocations,
    );

    // The latest payment (p2) is trimmed first; its freed 5.000 then pays
    // e2 (3.000) and the rest stays as credit.
    expect(shape(omr, rows), {'p1→e1': 4000, 'p2→e1': 1000, 'p2→e2': 3000});
    final ledger = PayLaterLedger.build(
      tab: _tab('OMR'),
      purchases: purchases,
      payments: payments,
      allocations: rows,
      today: _now,
    );
    expect(omr.toUnits(ledger.owed), 0);
    expect(omr.toUnits(ledger.credit), 2000);
  });

  test('purchase reduced trims automatic before manual', () {
    final payments = [
      _payment('p1', 4.0, DateTime(2026, 11, 3)),
      _payment('p2', 6.0, DateTime(2026, 11, 4)),
    ];
    final allocations = [
      _alloc('p1', 'e1', 4.0),
      _alloc('p2', 'e1', 6.0, isManual: true),
    ];
    final rows = reconciled(
      _allocator('OMR'),
      purchases: [_purchase('e1', 7.0, DateTime(2026, 11, 1))],
      payments: payments,
      allocations: allocations,
    );
    // p2 is later but manual: the automatic p1 row gives up the 3.000.
    expect(shape(omr, rows), {'p1→e1': 1000, 'p2→e1*': 6000});
  });

  test('deleted purchase: freed money moves on; with nothing owing it stays '
      'as credit', () {
    final payments = [_payment('p1', 3.0, DateTime(2026, 11, 4))];
    final allocations = [_alloc('p1', 'e1', 2.0), _alloc('p1', 'e2', 1.0)];
    final e2 = _purchase('e2', 4.0, DateTime(2026, 11, 2));

    // e1 deleted: its 2.000 moves to e2, which still owed 3.000.
    final allocator = _allocator('OMR');
    final diff = allocator.reconcile(
      purchases: [e2],
      payments: payments,
      allocations: allocations,
    );
    expect(diff.deletes, {'p1:e1'});
    expect(omr.toUnits(diff.updates['p1:e2']!), 3000);
    expect(diff.inserts, isEmpty);

    // e1 and e2 deleted: nothing owes, so the payment is all credit.
    final gone = allocator.reconcile(
      purchases: const [],
      payments: payments,
      allocations: allocations,
    );
    expect(gone.deletes, {'p1:e1', 'p1:e2'});
    expect(gone.updates, isEmpty);
    expect(gone.inserts, isEmpty);
    final ledger = PayLaterLedger.build(
      tab: _tab('OMR'),
      purchases: const [],
      payments: payments,
      allocations: _apply(allocations, gone),
      today: _now,
    );
    expect(omr.toUnits(ledger.owed), 0);
    expect(omr.toUnits(ledger.credit), 3000);
  });

  test('deleted payment: its rows go and the purchases owe again', () {
    final purchases = [_purchase('e1', 2.0, DateTime(2026, 11, 1))];
    final diff = _allocator('OMR').reconcile(
      purchases: purchases,
      payments: const [],
      allocations: [_alloc('p1', 'e1', 2.0)],
    );
    expect(diff.deletes, {'p1:e1'});
    expect(diff.updates, isEmpty);
    expect(diff.inserts, isEmpty);
  });

  test('invariant: after reconcile owed == 0 or credit == 0', () {
    final random = Random(42);
    const currencies = ['OMR', 'USD', 'JPY', 'INR'];
    for (var scenario = 0; scenario < 200; scenario++) {
      final currency = currencies[random.nextInt(currencies.length)];
      final money = MoneyMath.forCurrency(currency);
      double amount(int maxUnits) =>
          money.toAmount(1 + random.nextInt(maxUnits));
      final start = DateTime(2026, 10, 25);

      final purchases = [
        for (var i = 0; i < 1 + random.nextInt(6); i++)
          _purchase(
            'e$i',
            amount(5 * money.scale),
            start.add(Duration(hours: 24 * random.nextInt(5) + 1)),
            createdAt: DateTime(2026, 10, 1, 0, i),
          ),
      ];
      final payments = [
        for (var i = 0; i < random.nextInt(5); i++)
          _payment(
            'p$i',
            amount(6 * money.scale),
            start.add(Duration(hours: 24 * random.nextInt(8) + 1)),
            createdAt: DateTime(2026, 10, 2, 0, i),
          ),
      ];
      // Stale rows: some over a purchase or payment, some to rows that are
      // gone (deleted purchase e9 / payment p9), manual or not.
      final allocations = <PaymentAllocation>[];
      final paymentIds = [...payments.map((p) => p.id), 'p9'];
      final purchaseIds = [...purchases.map((e) => e.id), 'e9'];
      for (final paymentId in paymentIds) {
        for (final expenseId in purchaseIds) {
          if (random.nextInt(3) != 0) continue;
          allocations.add(
            _alloc(
              paymentId,
              expenseId,
              amount(4 * money.scale),
              isManual: random.nextBool(),
            ),
          );
        }
      }

      final allocator = _allocator(currency);
      final diff = allocator.reconcile(
        purchases: purchases,
        payments: payments,
        allocations: allocations,
      );
      final rows = _apply(allocations, diff);
      final why = 'scenario $scenario ($currency)';

      // Every row is positive, points at a real payment and purchase, and
      // each (payment, purchase) pair appears once.
      final pairs = <String>{};
      final paid = <String, int>{};
      final applied = <String, int>{};
      for (final a in rows) {
        final units = money.toUnits(a.amount);
        expect(units, greaterThan(0), reason: why);
        expect(paymentIds.take(payments.length), contains(a.paymentId));
        expect(purchaseIds.take(purchases.length), contains(a.expenseId));
        expect(pairs.add('${a.paymentId}|${a.expenseId}'), isTrue);
        paid.update(a.expenseId, (v) => v + units, ifAbsent: () => units);
        applied.update(a.paymentId, (v) => v + units, ifAbsent: () => units);
      }
      for (final e in purchases) {
        expect(
          paid[e.id] ?? 0,
          lessThanOrEqualTo(money.toUnits(e.amount)),
          reason: why,
        );
      }
      for (final p in payments) {
        expect(
          applied[p.id] ?? 0,
          lessThanOrEqualTo(money.toUnits(p.amount)),
          reason: why,
        );
      }

      final ledger = PayLaterLedger.build(
        tab: _tab(currency),
        purchases: purchases,
        payments: payments,
        allocations: rows,
        today: _now,
      );
      final owed = money.toUnits(ledger.owed);
      final credit = money.toUnits(ledger.credit);
      expect(owed == 0 || credit == 0, isTrue, reason: why);
      expect(owed, greaterThanOrEqualTo(0), reason: why);
      expect(credit, greaterThanOrEqualTo(0), reason: why);
      expect(
        owed - credit,
        money.sumUnits(purchases.map((e) => e.amount)) -
            money.sumUnits(payments.map((p) => p.amount)),
        reason: why,
      );

      // A second pass has nothing to do.
      expect(
        allocator
            .reconcile(
              purchases: purchases,
              payments: payments,
              allocations: rows,
            )
            .isEmpty,
        isTrue,
        reason: why,
      );
    }
  });

  test('reconcile on reconciled input returns an empty diff', () {
    final purchases = [
      _purchase('e1', 1.0, DateTime(2026, 11, 1)),
      _purchase('e2', 1.0, DateTime(2026, 11, 2)),
    ];
    // Owing, nothing unapplied.
    final owing = _allocator('OMR').reconcile(
      purchases: purchases,
      payments: [_payment('p1', 1.5, DateTime(2026, 11, 3))],
      allocations: [
        _alloc('p1', 'e1', 1.0),
        _alloc('p1', 'e2', 0.5, isManual: true),
      ],
    );
    expect(owing.isEmpty, isTrue);
    expect(owing, const AllocationDiff());

    // In credit, nothing owing.
    final credit = _allocator('OMR').reconcile(
      purchases: purchases,
      payments: [_payment('p1', 3.0, DateTime(2026, 11, 3))],
      allocations: [_alloc('p1', 'e1', 1.0), _alloc('p1', 'e2', 1.0)],
    );
    expect(credit.isEmpty, isTrue);

    // Nothing at all.
    expect(
      _allocator('OMR')
          .reconcile(
            purchases: const [],
            payments: const [],
            allocations: const [],
          )
          .isEmpty,
      isTrue,
    );
  });

  test('omr three meals partial payment is exact', () {
    final purchases = [
      _purchase('meal1', 0.350, DateTime(2026, 11, 1)),
      _purchase('meal2', 0.350, DateTime(2026, 11, 2)),
      _purchase('meal3', 0.350, DateTime(2026, 11, 3)),
    ];
    final payments = [_payment('p1', 0.700, DateTime(2026, 11, 4))];
    final rows = reconciled(
      _allocator('OMR'),
      purchases: purchases,
      payments: payments,
    );
    expect(shape(omr, rows), {'p1→meal1': 350, 'p1→meal2': 350});
    // The stored amounts are the exact decimals, not 0.35000000000000003.
    expect(rows.map((a) => a.amount.toString()), ['0.35', '0.35']);

    final ledger = PayLaterLedger.build(
      tab: _tab('OMR'),
      purchases: purchases,
      payments: payments,
      allocations: rows,
      today: _now,
    );
    PurchaseLine line(String id) =>
        ledger.purchases.singleWhere((l) => l.expense.id == id);
    expect(line('meal1').status, PurchaseStatus.paid);
    expect(line('meal2').status, PurchaseStatus.paid);
    expect(line('meal3').status, PurchaseStatus.unpaid);
    expect(line('meal3').owes.toString(), '0.35');
    expect(ledger.owed.toString(), '0.35');
    expect(omr.toUnits(ledger.credit), 0);
  });

  test('zero-decimal currency (JPY) rounding', () {
    final jpy = MoneyMath.forCurrency('JPY');
    // JPY works at two decimals (the forms accept them): 100.5 is kept, and
    // 33.335 rounds half away from zero to 33.34.
    final purchases = [
      _purchase('e1', 100.5, DateTime(2026, 11, 1)),
      _purchase('e2', 33.335, DateTime(2026, 11, 2)),
      _purchase('e3', 200, DateTime(2026, 11, 3)),
    ];
    final payments = [_payment('p1', 150, DateTime(2026, 11, 4))];
    final rows = reconciled(
      _allocator('JPY'),
      purchases: purchases,
      payments: payments,
    );
    expect(shape(jpy, rows), {'p1→e1': 10050, 'p1→e2': 3334, 'p1→e3': 1616});
    expect(rows.map((a) => a.amount.toString()), ['100.5', '33.34', '16.16']);

    final ledger = PayLaterLedger.build(
      tab: _tab('JPY'),
      purchases: purchases,
      payments: payments,
      allocations: rows,
      today: _now,
    );
    expect(jpy.toUnits(ledger.owed), 18384);
    expect(jpy.toUnits(ledger.credit), 0);
  });
}
