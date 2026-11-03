import 'dart:developer' as developer;

import '../entities/pay_later_failure.dart';
import '../entities/tab_ledger.dart';
import '../repository/pay_later_repository.dart';
import '../services/pay_later_ledger.dart';

/// Builds a tab's ledger from stored rows. Reads only: no reconcile, no
/// writes. The rows are read in one transaction, so a write can't land
/// between them (allocations always match the purchases and payments read).
class GetTabLedgerUseCase {
  final PayLaterRepository _repository;
  final DateTime Function() _clock;

  GetTabLedgerUseCase({
    required PayLaterRepository repository,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? DateTime.now;

  Future<PayLaterResult<TabLedger>> call(String tabId) async {
    try {
      final ledger = await _repository.transaction(() async {
        final tab = await _repository.getTab(tabId);
        if (tab == null) return null;
        return PayLaterLedger.build(
          tab: tab,
          purchases: await _repository.purchasesOf(tabId),
          payments: await _repository.paymentsOf(tabId),
          allocations: await _repository.allocationsOf(tabId),
          today: _clock(),
        );
      });
      if (ledger == null) {
        return const PayLaterError(
          PayLaterFailure(
            type: PayLaterErrorType.notFound,
            message: 'Tab not found',
          ),
        );
      }
      return PayLaterSuccess(ledger);
    } catch (e) {
      developer.log('Failed to load tab ledger: $e', name: 'GetTabLedger');
      return PayLaterError(
        PayLaterFailure(
          type: PayLaterErrorType.databaseFailure,
          message: 'Failed to load tab: $e',
        ),
      );
    }
  }
}
