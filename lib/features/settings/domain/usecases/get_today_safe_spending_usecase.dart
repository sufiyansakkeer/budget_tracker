import 'package:flutter/foundation.dart';

import '../../../dashboard/domain/entities/budget_daily_limit_entity.dart';
import '../../../dashboard/domain/usecases/get_spending_targets_usecase.dart';

/// Per-budget safe spending result.
class PerBudgetSafeSpendingResult {
  final List<BudgetDailyLimitEntity> budgetLimits;

  const PerBudgetSafeSpendingResult({required this.budgetLimits});
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

  /// Returns per-budget safe spending amounts for [referenceDate] (today when
  /// omitted): the budgets running that day, each with the amount the
  /// dashboard will show that day if nothing more is spent before it. No
  /// budget running gives an empty list; null means the amounts could not be
  /// worked out.
  Future<PerBudgetSafeSpendingResult?> callPerBudget({
    DateTime? referenceDate,
  }) async {
    final result = await _spendingTargetsUseCase.callPerBudget(
      referenceDate: referenceDate,
    );

    return switch (result) {
      PerBudgetSpendingTargetNoBudget() => () {
        debugPrint('[Notification] No active budget found');
        return const PerBudgetSafeSpendingResult(budgetLimits: []);
      }(),
      PerBudgetSpendingTargetError(:final failure) => () {
        debugPrint('[Notification] Spending target error: ${failure.message}');
        return null;
      }(),
      PerBudgetSpendingTargetSuccess(:final budgetLimits) => () {
        debugPrint(
          '[Notification] Per-budget safe spending: '
          '${budgetLimits.length} budgets',
        );
        return PerBudgetSafeSpendingResult(budgetLimits: budgetLimits);
      }(),
    };
  }
}
