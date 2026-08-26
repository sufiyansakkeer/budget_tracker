import 'package:flutter/foundation.dart';

import '../../../dashboard/domain/usecases/get_spending_targets_usecase.dart';

/// Result of the safe spending calculation.
class SafeSpendingResult {
  final double amount;
  final String currency;

  const SafeSpendingResult({required this.amount, required this.currency});
}

/// Calculates today's safe spending amount using [GetSpendingTargetsUseCase].
///
/// This ensures the notification system and the Dashboard always show
/// the same value — the combined daily target across all active budgets.
class GetTodaySafeSpendingUseCase {
  final GetSpendingTargetsUseCase _spendingTargetsUseCase;

  const GetTodaySafeSpendingUseCase({
    required GetSpendingTargetsUseCase spendingTargetsUseCase,
  }) : _spendingTargetsUseCase = spendingTargetsUseCase;

  /// Returns today's safe spending amount and currency code.
  ///
  /// Falls back to [fallbackCurrency] when no active budget is found.
  Future<SafeSpendingResult?> call({String fallbackCurrency = 'INR'}) async {
    final result = await _spendingTargetsUseCase();

    return switch (result) {
      SpendingTargetNoBudget() => () {
          debugPrint('[Notification] No active budget found');
          return null;
        }(),
      SpendingTargetError(:final failure) => () {
          debugPrint('[Notification] Spending target error: ${failure.message}');
          return null;
        }(),
      SpendingTargetSuccess(:final data) => () {
          debugPrint(
            '[Notification] Today\'s safe spending: '
            '${data.dailyTarget} ${data.currency}',
          );
          return SafeSpendingResult(
            amount: data.dailyTarget,
            currency: data.currency,
          );
        }(),
    };
  }
}
