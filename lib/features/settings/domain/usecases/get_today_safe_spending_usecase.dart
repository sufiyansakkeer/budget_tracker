import 'package:flutter/foundation.dart';

import '../../../dashboard/domain/entities/budget_daily_limit_entity.dart';
import '../../../dashboard/domain/usecases/get_spending_targets_usecase.dart';

/// Result of the safe spending calculation.
class SafeSpendingResult {
  final double amount;
  final String currency;

  const SafeSpendingResult({required this.amount, required this.currency});
}

/// Per-budget safe spending result.
class PerBudgetSafeSpendingResult {
  final List<BudgetDailyLimitEntity> budgetLimits;
  final double combinedAmount;
  final String currency;

  const PerBudgetSafeSpendingResult({
    required this.budgetLimits,
    required this.combinedAmount,
    required this.currency,
  });
}

/// Calculates today's safe spending amount using [GetSpendingTargetsUseCase].
///
/// This ensures the notification system and the Dashboard always show
/// the same value — per-budget daily limits, NOT a combined total.
class GetTodaySafeSpendingUseCase {
  final GetSpendingTargetsUseCase _spendingTargetsUseCase;

  const GetTodaySafeSpendingUseCase({
    required GetSpendingTargetsUseCase spendingTargetsUseCase,
  }) : _spendingTargetsUseCase = spendingTargetsUseCase;

  /// Returns today's safe spending amount and currency code (legacy combined).
  @Deprecated('Use callPerBudget() for per-budget safe spending')
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

  /// Returns per-budget safe spending amounts.
  Future<PerBudgetSafeSpendingResult?> callPerBudget({
    String fallbackCurrency = 'INR',
  }) async {
    final result = await _spendingTargetsUseCase.callPerBudget();

    return switch (result) {
      PerBudgetSpendingTargetNoBudget() => () {
        debugPrint('[Notification] No active budget found');
        return null;
      }(),
      PerBudgetSpendingTargetError(:final failure) => () {
        debugPrint('[Notification] Spending target error: ${failure.message}');
        return null;
      }(),
      PerBudgetSpendingTargetSuccess(
        :final budgetLimits,
        :final combinedDailyTarget,
        :final currency,
      ) =>
        () {
          debugPrint(
            '[Notification] Per-budget safe spending: '
            '${budgetLimits.length} budgets, '
            'combined: $combinedDailyTarget $currency',
          );
          return PerBudgetSafeSpendingResult(
            budgetLimits: budgetLimits,
            combinedAmount: combinedDailyTarget,
            currency: currency,
          );
        }(),
    };
  }
}
