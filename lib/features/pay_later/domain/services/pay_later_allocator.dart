import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/currency/money_math.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../entities/payment_allocation.dart';
import '../entities/tab_payment.dart';
import 'fifo_order.dart';

/// The writes that bring a tab's stored allocations back to the invariants.
class AllocationDiff extends Equatable {
  /// New automatic allocations.
  final List<PaymentAllocation> inserts;

  /// Allocation id → its new amount.
  final Map<String, double> updates;

  /// Allocation ids to remove.
  final Set<String> deletes;

  const AllocationDiff({
    this.inserts = const [],
    this.updates = const {},
    this.deletes = const {},
  });

  /// Nothing to write.
  bool get isEmpty => inserts.isEmpty && updates.isEmpty && deletes.isEmpty;

  @override
  List<Object?> get props => [inserts, updates, deletes];
}

/// Decides which purchases each payment pays (spec §5) and repairs the
/// allocations after payments or purchases change.
///
/// Pure: works on in-memory rows and returns new rows or an
/// [AllocationDiff]; the repository writes them. Every sum and comparison
/// is done in integer units of the tab's currency ([MoneyMath]).
class PayLaterAllocator {
  PayLaterAllocator({
    required String currency,
    String Function()? newId,
    DateTime Function()? clock,
  }) : _money = MoneyMath.forCurrency(currency),
       _newId = newId ?? (() => const Uuid().v4()),
       _clock = clock ?? DateTime.now;

  final MoneyMath _money;
  final String Function() _newId;
  final DateTime Function() _clock;

  /// Manual allocations for a new payment: chosen purchases in FIFO order,
  /// each capped at what it still owes. Leftover is left for [reconcile].
  ///
  /// [existing] are the tab's stored allocations (other payments); a chosen
  /// purchase that owes nothing gets no row, and ids in [chosenExpenseIds]
  /// that are not among [purchases] are ignored.
  List<PaymentAllocation> allocateChosen({
    required TabPayment payment,
    required List<ExpenseEntity> purchases,
    required List<PaymentAllocation> existing,
    required Set<String> chosenExpenseIds,
  }) {
    final paid = <String, int>{};
    var remaining = _money.toUnits(payment.amount);
    for (final allocation in existing) {
      final units = _money.toUnits(allocation.amount);
      paid.update(
        allocation.expenseId,
        (v) => v + units,
        ifAbsent: () => units,
      );
      if (allocation.paymentId == payment.id) remaining -= units;
    }

    final chosen = [
      for (final purchase in purchases)
        if (chosenExpenseIds.contains(purchase.id)) purchase,
    ]..sort(_purchaseOrder);

    final createdAt = _clock();
    final rows = <PaymentAllocation>[];
    for (final purchase in chosen) {
      if (remaining <= 0) break;
      final owes = _money.toUnits(purchase.amount) - (paid[purchase.id] ?? 0);
      if (owes <= 0) continue;
      final take = owes < remaining ? owes : remaining;
      remaining -= take;
      rows.add(
        PaymentAllocation(
          id: _newId(),
          paymentId: payment.id,
          expenseId: purchase.id,
          amount: _money.toAmount(take),
          isManual: true,
          createdAt: createdAt,
        ),
      );
    }
    return rows;
  }

  /// Brings stored allocations back to the invariants (spec §3, §5): no
  /// purchase paid above its amount, no payment applied above its amount,
  /// and no payment money unapplied while a purchase owes (owed == 0 or
  /// credit == 0).
  ///
  /// 1. Rows whose payment or purchase is not in the inputs are deleted.
  /// 2. A payment applied above its amount has rows trimmed: automatic
  ///    before manual, then newest purchase first.
  /// 3. A purchase paid above its amount has rows trimmed: automatic before
  ///    manual, then latest payment first.
  /// 4. Each payment's unapplied money, oldest payment first, goes FIFO to
  ///    purchases that still owe (added to an existing row for the pair, or
  ///    a new automatic row).
  ///
  /// Running it on its own output returns an empty diff.
  AllocationDiff reconcile({
    required List<ExpenseEntity> purchases,
    required List<TabPayment> payments,
    required List<PaymentAllocation> allocations,
  }) {
    final orderedPurchases = [...purchases]..sort(_purchaseOrder);
    final orderedPayments = [...payments]..sort(_paymentOrder);
    final purchaseRank = {
      for (var i = 0; i < orderedPurchases.length; i++)
        orderedPurchases[i].id: i,
    };
    final paymentRank = {
      for (var i = 0; i < orderedPayments.length; i++) orderedPayments[i].id: i,
    };

    // 1. Drop rows pointing at a payment or purchase that is gone.
    final deletes = <String>{};
    final rows = <_Row>[];
    final rowByPair = <(String, String), _Row>{};
    for (final allocation in allocations) {
      if (!paymentRank.containsKey(allocation.paymentId) ||
          !purchaseRank.containsKey(allocation.expenseId)) {
        deletes.add(allocation.id);
        continue;
      }
      final units = _money.toUnits(allocation.amount);
      final row = _Row(
        original: allocation,
        paymentId: allocation.paymentId,
        expenseId: allocation.expenseId,
        isManual: allocation.isManual,
        originalUnits: units,
        // A non-positive stored amount carries no money.
        units: units > 0 ? units : 0,
      );
      rows.add(row);
      rowByPair.putIfAbsent(row.pair, () => row);
    }

    // 2. Payments applied above their amount: automatic first, then newest
    //    purchase first.
    for (final payment in orderedPayments) {
      final own = [
        for (final row in rows)
          if (row.paymentId == payment.id) row,
      ];
      _trim(
        own,
        excess: _sum(own) - _money.toUnits(payment.amount),
        newestFirst: (a, b) =>
            purchaseRank[b.expenseId]!.compareTo(purchaseRank[a.expenseId]!),
      );
    }

    // 3. Purchases paid above their amount: automatic first, then latest
    //    payment first.
    for (final purchase in orderedPurchases) {
      final own = [
        for (final row in rows)
          if (row.expenseId == purchase.id) row,
      ];
      _trim(
        own,
        excess: _sum(own) - _money.toUnits(purchase.amount),
        newestFirst: (a, b) =>
            paymentRank[b.paymentId]!.compareTo(paymentRank[a.paymentId]!),
      );
    }

    // 4. Unapplied money, oldest payment first, FIFO to what still owes.
    final owes = {
      for (final purchase in orderedPurchases)
        purchase.id: _money.toUnits(purchase.amount),
    };
    final unapplied = {
      for (final payment in orderedPayments)
        payment.id: _money.toUnits(payment.amount),
    };
    for (final row in rows) {
      owes[row.expenseId] = owes[row.expenseId]! - row.units;
      unapplied[row.paymentId] = unapplied[row.paymentId]! - row.units;
    }
    for (final payment in orderedPayments) {
      var left = unapplied[payment.id]!;
      for (final purchase in orderedPurchases) {
        if (left <= 0) break;
        final owing = owes[purchase.id]!;
        if (owing <= 0) continue;
        final take = owing < left ? owing : left;
        left -= take;
        owes[purchase.id] = owing - take;
        final pair = (payment.id, purchase.id);
        final row = rowByPair.putIfAbsent(pair, () {
          final row = _Row(
            paymentId: payment.id,
            expenseId: purchase.id,
            isManual: false,
            originalUnits: 0,
            units: 0,
          );
          rows.add(row);
          return row;
        });
        row.units += take;
      }
    }

    // 5. The diff against the input rows.
    final inserts = <PaymentAllocation>[];
    final updates = <String, double>{};
    DateTime? createdAt;
    for (final row in rows) {
      final original = row.original;
      if (original == null) {
        if (row.units <= 0) continue;
        inserts.add(
          PaymentAllocation(
            id: _newId(),
            paymentId: row.paymentId,
            expenseId: row.expenseId,
            amount: _money.toAmount(row.units),
            isManual: false,
            createdAt: createdAt ??= _clock(),
          ),
        );
      } else if (row.units <= 0) {
        deletes.add(original.id);
      } else if (row.units != row.originalUnits) {
        updates[original.id] = _money.toAmount(row.units);
      }
    }
    return AllocationDiff(inserts: inserts, updates: updates, deletes: deletes);
  }

  /// Takes [excess] units off [rows]: automatic rows before manual ones,
  /// each group in [newestFirst] order.
  static void _trim(
    List<_Row> rows, {
    required int excess,
    required int Function(_Row a, _Row b) newestFirst,
  }) {
    if (excess <= 0) return;
    rows.sort((a, b) {
      if (a.isManual != b.isManual) return a.isManual ? 1 : -1;
      return newestFirst(a, b);
    });
    for (final row in rows) {
      if (excess <= 0) return;
      final cut = row.units < excess ? row.units : excess;
      row.units -= cut;
      excess -= cut;
    }
  }

  static int _sum(List<_Row> rows) {
    var sum = 0;
    for (final row in rows) {
      sum += row.units;
    }
    return sum;
  }

  /// FIFO ([FifoOrder], shared with `PayLaterLedger`).
  static int _purchaseOrder(ExpenseEntity a, ExpenseEntity b) =>
      FifoOrder.purchases(a, b);

  static int _paymentOrder(TabPayment a, TabPayment b) =>
      FifoOrder.payments(a, b);
}

/// One allocation being reconciled, in units.
class _Row {
  _Row({
    this.original,
    required this.paymentId,
    required this.expenseId,
    required this.isManual,
    required this.originalUnits,
    required this.units,
  });

  /// The stored allocation; null for a row reconcile adds.
  final PaymentAllocation? original;
  final String paymentId;
  final String expenseId;
  final bool isManual;
  final int originalUnits;
  int units;

  (String, String) get pair => (paymentId, expenseId);
}
