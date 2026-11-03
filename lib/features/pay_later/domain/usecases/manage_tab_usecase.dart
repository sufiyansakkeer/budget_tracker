import 'dart:developer' as developer;

import '../../../../core/currency/money_math.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../entities/pay_later_failure.dart';
import '../entities/pay_later_tab.dart';
import '../entities/settle_rhythm.dart';
import '../repository/pay_later_repository.dart';
import '../services/pay_later_ledger.dart';
import '../validators/pay_later_tab_validator.dart';

/// Creates, edits, archives, unarchives and deletes tabs (spec §3, §7).
///
/// Each check-then-write (currency in use, balance, activity) runs in one
/// transaction, so a purchase or payment can't land between the check and
/// the write.
class ManageTabUseCase {
  final PayLaterRepository _repository;
  final DateTime Function() _clock;

  ManageTabUseCase({
    required PayLaterRepository repository,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? DateTime.now;

  Future<PayLaterResult<PayLaterTab>> create(PayLaterTab tab) =>
      _run('create tab', () async {
        final invalid = PayLaterTabValidator.validate(
          tab,
          today: _clock(),
          isCreate: true,
        );
        if (invalid != null) {
          return _fail(PayLaterErrorType.invalidInput, invalid);
        }
        final now = _clock();
        final saved = tab.copyWith(
          name: tab.name.trim(),
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );
        await _repository.createTab(saved);
        return PayLaterSuccess(saved);
      });

  /// A currency change is refused once the tab has purchases or payments.
  Future<PayLaterResult<PayLaterTab>> update(PayLaterTab tab) => _run(
    'update tab',
    () => _repository.transaction(() async {
      final invalid = PayLaterTabValidator.validate(
        tab,
        today: _clock(),
        isCreate: false,
      );
      if (invalid != null) {
        return _fail(PayLaterErrorType.invalidInput, invalid);
      }
      final existing = await _repository.getTab(tab.id);
      if (existing == null) return _notFound();
      if (existing.currency != tab.currency &&
          await _repository.tabHasActivity(tab.id)) {
        return _fail(
          PayLaterErrorType.inUse,
          "This tab already has purchases or payments, so its currency can't change.",
        );
      }
      final saved = tab.copyWith(
        name: tab.name.trim(),
        rhythm: _rolledRhythm(existing.rhythm, tab.rhythm),
        createdAt: existing.createdAt,
        // Archiving only goes through archive/unarchive (balance check).
        isArchived: existing.isArchived,
        updatedAt: _clock(),
      );
      await _repository.updateTab(saved);
      return PayLaterSuccess(saved);
    }),
  );

  /// Spec §4: when the stored manual settle-up date has passed and the user
  /// sets a different date, the old date becomes the anchor, so purchases
  /// before it stay in one "earlier" period settling on it. Any other change
  /// keeps the incoming rhythm as it is.
  SettleRhythm _rolledRhythm(SettleRhythm stored, SettleRhythm incoming) {
    if (stored is! ManualDate || incoming is! ManualDate) return incoming;
    final oldDate = stored.nextSettleDate;
    final newDate = incoming.nextSettleDate;
    if (oldDate == null || !oldDate.dateOnly.isBefore(_clock().dateOnly)) {
      return incoming;
    }
    if (newDate != null && newDate.dateOnly == oldDate.dateOnly) {
      return incoming;
    }
    return ManualDate(nextSettleDate: newDate, anchor: oldDate.dateOnly);
  }

  /// Refused while the tab owes money or holds credit.
  Future<PayLaterResult<PayLaterTab>> archive(String id) => _run(
    'archive tab',
    () => _repository.transaction(() async {
      final tab = await _repository.getTab(id);
      if (tab == null) return _notFound();
      final ledger = PayLaterLedger.build(
        tab: tab,
        purchases: await _repository.purchasesOf(id),
        payments: await _repository.paymentsOf(id),
        allocations: await _repository.allocationsOf(id),
        today: _clock(),
      );
      final money = MoneyMath.forCurrency(tab.currency);
      if (money.toUnits(ledger.owed) != 0 ||
          money.toUnits(ledger.credit) != 0) {
        return _fail(
          PayLaterErrorType.hasBalance,
          'Settle this tab before archiving it. It still owes money or holds credit.',
        );
      }
      final saved = tab.copyWith(isArchived: true, updatedAt: _clock());
      await _repository.updateTab(saved);
      return PayLaterSuccess(saved);
    }),
  );

  Future<PayLaterResult<PayLaterTab>> unarchive(String id) =>
      _run('unarchive tab', () async {
        final tab = await _repository.getTab(id);
        if (tab == null) return _notFound();
        final saved = tab.copyWith(isArchived: false, updatedAt: _clock());
        await _repository.updateTab(saved);
        return PayLaterSuccess(saved);
      });

  /// Refused when the tab has purchases or payments.
  Future<PayLaterResult<void>> delete(String id) => _run(
    'delete tab',
    () => _repository.transaction(() async {
      if (await _repository.getTab(id) == null) return _notFound();
      if (await _repository.tabHasActivity(id)) {
        return _fail(
          PayLaterErrorType.inUse,
          "This tab has purchases or payments, so it can't be deleted. Archive it instead.",
        );
      }
      await _repository.deleteTab(id);
      return const PayLaterSuccess(null);
    }),
  );

  Future<PayLaterResult<T>> _run<T>(
    String what,
    Future<PayLaterResult<T>> Function() body,
  ) async {
    try {
      return await body();
    } catch (e) {
      developer.log('Failed to $what: $e', name: 'ManageTab');
      return _fail(PayLaterErrorType.databaseFailure, 'Failed to $what: $e');
    }
  }

  PayLaterResult<T> _notFound<T>() =>
      _fail(PayLaterErrorType.notFound, 'Tab not found');

  PayLaterResult<T> _fail<T>(PayLaterErrorType type, String message) =>
      PayLaterError(PayLaterFailure(type: type, message: message));
}
