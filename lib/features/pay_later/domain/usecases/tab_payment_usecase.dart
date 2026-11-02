import 'dart:developer' as developer;

import '../../../../core/currency/money_math.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../entities/pay_later_failure.dart';
import '../entities/tab_payment.dart';
import '../repository/pay_later_repository.dart';
import '../services/pay_later_allocator.dart';
import '../services/pay_later_ledger.dart';
import 'reconcile_tab_usecase.dart';

/// Records, edits and deletes payments on a tab (spec §5).
///
/// Each write is one transaction that ends with the tab's reconcile, so the
/// payment and its allocations commit or roll back together. The checks
/// (owed, applied) are read inside that transaction: Drift runs the
/// database's transactions one at a time, so two payments can't both pass
/// the "not more than owed" check.
///
/// Callers notify `RefreshBuses.payLater` after a successful write; this
/// use case notifies nothing.
class TabPaymentUseCase {
  final PayLaterRepository _repository;
  final ReconcileTabUseCase _reconcileTab;
  final DateTime Function() _clock;

  TabPaymentUseCase({
    required PayLaterRepository repository,
    required ReconcileTabUseCase reconcileTab,
    DateTime Function()? clock,
  }) : _repository = repository,
       _reconcileTab = reconcileTab,
       _clock = clock ?? DateTime.now;

  /// [paymentId] is created once by the caller (the sheet, on open) and is the
  /// idempotency key: recording the same id twice returns the stored payment.
  ///
  /// The amount must be above zero and not above what the tab owes (in the
  /// tab currency's units); [paidDate] can't be after today. Money goes to
  /// [chosenExpenseIds] first (FIFO among them, each up to what it owes,
  /// marked manual); the rest goes FIFO to the tab's other purchases.
  Future<PayLaterResult<TabPayment>> record({
    required String paymentId,
    required String tabId,
    required double amount,
    required DateTime paidDate,
    String? note,
    Set<String> chosenExpenseIds = const {},
  }) => _run(
    'record payment',
    () => _repository.transaction(() async {
      // A second submit of the same sheet finds the first one's row.
      final stored = await _repository.getPayment(paymentId);
      if (stored != null) return _sameTab(stored, tabId);

      final tab = await _repository.getTab(tabId);
      if (tab == null) return _tabNotFound();
      final money = MoneyMath.forCurrency(tab.currency);
      final units = _positiveUnits(amount, money);
      if (units == null) return _amountNotPositive();
      if (_isAfterToday(paidDate)) return _futureDate();

      final purchases = await _repository.purchasesOf(tabId);
      final allocations = await _repository.allocationsOf(tabId);
      final ledger = PayLaterLedger.build(
        tab: tab,
        purchases: purchases,
        payments: await _repository.paymentsOf(tabId),
        allocations: allocations,
        today: _clock(),
      );
      if (units > money.toUnits(ledger.owed)) return _overpay();

      final onTab = {for (final p in purchases) p.id};
      if (!onTab.containsAll(chosenExpenseIds)) {
        return _fail(
          PayLaterErrorType.invalidInput,
          'Some chosen purchases are not on this tab.',
        );
      }

      final now = _clock();
      final payment = TabPayment(
        id: paymentId,
        tabId: tabId,
        amount: money.toAmount(units),
        paidDate: paidDate,
        note: _cleanNote(note),
        createdAt: now,
        updatedAt: now,
      );
      try {
        await _repository.createPayment(payment);
      } catch (e) {
        // The primary key refused a second row with this id: the payment
        // is already stored, so answer with it. Logged first, so another
        // cause isn't hidden when there is no stored row.
        developer.log(
          'Creating payment $paymentId failed, looking for a stored one: $e',
          name: 'TabPayment',
        );
        final clash = await _repository.getPayment(paymentId);
        if (clash == null) rethrow;
        return _sameTab(clash, tabId);
      }

      // Chosen rows first, then reconcile spreads the leftover FIFO. The
      // other way round, reconcile would already have spent the money.
      final chosen = PayLaterAllocator(currency: tab.currency, clock: _clock)
          .allocateChosen(
            payment: payment,
            purchases: purchases,
            existing: allocations,
            chosenExpenseIds: chosenExpenseIds,
          );
      if (chosen.isNotEmpty) {
        await _repository.applyDiff(AllocationDiff(inserts: chosen));
      }
      await _reconcileTab(tabId);
      return PayLaterSuccess(payment);
    }),
  );

  /// Saves an edit of [payment] (amount, date, note). A lower amount trims
  /// its allocations (automatic first, newest purchase first); a higher one
  /// is refused above what the tab owes plus what this payment already
  /// covers, and the extra goes FIFO. Date or note alone moves no money.
  /// A payment can't move to another tab.
  Future<PayLaterResult<TabPayment>> update(TabPayment payment) => _run(
    'update payment',
    () => _repository.transaction(() async {
      final stored = await _repository.getPayment(payment.id);
      if (stored == null) return _paymentNotFound();
      if (stored.tabId != payment.tabId) {
        return _fail(
          PayLaterErrorType.invalidInput,
          "A payment can't move to another tab.",
        );
      }
      final tab = await _repository.getTab(stored.tabId);
      if (tab == null) return _tabNotFound();
      final money = MoneyMath.forCurrency(tab.currency);
      final units = _positiveUnits(payment.amount, money);
      if (units == null) return _amountNotPositive();
      if (_isAfterToday(payment.paidDate)) return _futureDate();

      // Only a raise is checked: a payment holding credit keeps its amount
      // when just its date or note changes.
      if (units > money.toUnits(stored.amount)) {
        final allocations = await _repository.allocationsOf(tab.id);
        final ledger = PayLaterLedger.build(
          tab: tab,
          purchases: await _repository.purchasesOf(tab.id),
          payments: await _repository.paymentsOf(tab.id),
          allocations: allocations,
          today: _clock(),
        );
        final applied = money.sumUnits([
          for (final a in allocations)
            if (a.paymentId == stored.id) a.amount,
        ]);
        final limit = money.toUnits(ledger.owed) + applied;
        if (units > limit) return _overpay();
      }

      final saved = TabPayment(
        id: stored.id,
        tabId: stored.tabId,
        amount: money.toAmount(units),
        paidDate: payment.paidDate,
        note: _cleanNote(payment.note),
        createdAt: stored.createdAt,
        updatedAt: _clock(),
      );
      await _repository.updatePayment(saved);
      await _reconcileTab(tab.id);
      return PayLaterSuccess(saved);
    }),
  );

  /// Deletes a payment: its allocations go with it, so those purchases owe
  /// again (unless the tab's credit covers them). A missing id is
  /// `notFound` and writes nothing.
  Future<PayLaterResult<void>> delete(String paymentId) => _run(
    'delete payment',
    () => _repository.transaction(() async {
      final stored = await _repository.getPayment(paymentId);
      if (stored == null) return _paymentNotFound<void>();
      await _repository.deletePayment(paymentId);
      await _reconcileTab(stored.tabId);
      return const PayLaterSuccess<void>(null);
    }),
  );

  /// Owed after a payment of [amount] (for the sheet's preview). Never
  /// below zero; an amount at or below zero leaves owed as it is. Reads
  /// only, in one transaction (one consistent snapshot).
  Future<PayLaterResult<double>> owedAfter({
    required String tabId,
    required double amount,
  }) => _run(
    'load owed amount',
    () => _repository.transaction(() async {
      final tab = await _repository.getTab(tabId);
      if (tab == null) return _tabNotFound();
      final ledger = PayLaterLedger.build(
        tab: tab,
        purchases: await _repository.purchasesOf(tabId),
        payments: await _repository.paymentsOf(tabId),
        allocations: await _repository.allocationsOf(tabId),
        today: _clock(),
      );
      final money = MoneyMath.forCurrency(tab.currency);
      final paying = _positiveUnits(amount, money) ?? 0;
      final left = money.toUnits(ledger.owed) - paying;
      return PayLaterSuccess(money.toAmount(left > 0 ? left : 0));
    }),
  );

  /// [amount] in units when it is finite, within range and above zero
  /// after rounding; otherwise null.
  static int? _positiveUnits(double amount, MoneyMath money) {
    if (!MoneyMath.isWithinLimit(amount)) return null;
    final units = money.toUnits(amount);
    return units > 0 ? units : null;
  }

  bool _isAfterToday(DateTime date) => date.dateOnly.isAfter(_clock().dateOnly);

  static String? _cleanNote(String? note) {
    final trimmed = note?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// A stored payment answering a repeat of [paymentId]: success on the
  /// same tab, refused on another.
  static PayLaterResult<TabPayment> _sameTab(TabPayment stored, String tabId) {
    if (stored.tabId == tabId) return PayLaterSuccess(stored);
    return _fail(
      PayLaterErrorType.invalidInput,
      'This payment belongs to another tab.',
    );
  }

  Future<PayLaterResult<T>> _run<T>(
    String what,
    Future<PayLaterResult<T>> Function() body,
  ) async {
    try {
      return await body();
    } catch (e) {
      developer.log('Failed to $what: $e', name: 'TabPayment');
      return _fail(PayLaterErrorType.databaseFailure, 'Failed to $what: $e');
    }
  }

  static PayLaterResult<T> _tabNotFound<T>() =>
      _fail(PayLaterErrorType.notFound, 'Tab not found');

  static PayLaterResult<T> _paymentNotFound<T>() =>
      _fail(PayLaterErrorType.notFound, 'Payment not found');

  static PayLaterResult<T> _amountNotPositive<T>() =>
      _fail(PayLaterErrorType.invalidInput, 'Enter an amount above zero.');

  static PayLaterResult<T> _futureDate<T>() => _fail(
    PayLaterErrorType.invalidInput,
    "The payment date can't be after today.",
  );

  static PayLaterResult<T> _overpay<T>() =>
      _fail(PayLaterErrorType.invalidInput, "That's more than this tab owes.");

  static PayLaterResult<T> _fail<T>(PayLaterErrorType type, String message) =>
      PayLaterError(PayLaterFailure(type: type, message: message));
}
