import 'dart:developer' as developer;

import '../entities/pay_later_failure.dart';
import '../entities/pay_later_tab.dart';
import '../repository/pay_later_repository.dart';

/// Every tab, archived included; callers choose which to show (the expense
/// form lists only non-archived tabs). Reads only.
class GetTabsUseCase {
  final PayLaterRepository _repository;

  GetTabsUseCase({required PayLaterRepository repository})
    : _repository = repository;

  Future<PayLaterResult<List<PayLaterTab>>> call() async {
    try {
      return PayLaterSuccess(await _repository.getTabs());
    } catch (e) {
      developer.log('Failed to load tabs: $e', name: 'GetTabs');
      return PayLaterError(
        PayLaterFailure(
          type: PayLaterErrorType.databaseFailure,
          message: 'Failed to load tabs: $e',
        ),
      );
    }
  }
}
