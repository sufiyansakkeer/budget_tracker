import 'package:flutter/foundation.dart';

import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../budget/domain/services/budget_calculation_service.dart';
import '../../../budget/domain/usecases/get_budget_summary_usecase.dart';

/// Result of the safe spending calculation.
class SafeSpendingResult {
  final double amount;
  final String currency;

  const SafeSpendingResult({required this.amount, required this.currency});
}

/// Calculates today's safe spending amount using the same business logic
/// as the Dashboard's "Today's Safe Spending" section.
///
/// This ensures the notification system and the Dashboard always show
/// the same value for the same data and time.
class GetTodaySafeSpendingUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  const GetTodaySafeSpendingUseCase({
    required this.repository,
    required this.calculationService,
  });

  /// Returns today's safe spending amount and the budget's currency code.
  ///
  /// Falls back to [fallbackCurrency] when no active budget is found.
  Future<SafeSpendingResult?> call({String fallbackCurrency = 'INR'}) async {
    final activeId = await repository.getActiveBudgetId();
    if (activeId == null) {
      debugPrint('[Notification] No active budget found');
      return null;
    }

    debugPrint('[Notification] Active budget id: $activeId');

    final summaryUseCase = GetBudgetSummaryUseCase(
      repository: repository,
      calculationService: calculationService,
    );

    final result = await summaryUseCase(budgetId: activeId);

    return switch (result) {
      BudgetError(:final failure) => () {
          debugPrint('[Notification] Budget calculation error: ${failure.message}');
          return null;
        }(),
      BudgetSuccess(:final data) => () {
          debugPrint('[Notification] Today\'s safe spending: ${data.dailySafeSpending} ${data.currency}');
          return SafeSpendingResult(
            amount: data.dailySafeSpending,
            currency: data.currency,
          );
        }(),
    };
  }
}
