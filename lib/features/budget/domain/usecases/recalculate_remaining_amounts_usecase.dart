import '../repository/budget_repository.dart';
import '../services/budget_calculation_service.dart';

/// Brings every budget's stored remaining amount (`budgets.remaining_amount`)
/// back in line with its expenses.
///
/// The budget list, its "Total remaining" and the budget picker read that
/// stored value. Expense writes through the repository keep it current, but
/// bulk writes that go straight to the database (CSV/JSON import, backup
/// restore) do not, and values they left stale stayed wrong until the
/// budget's next expense change. Those writes call this afterwards, and app
/// start calls it once to repair values left stale before this existed.
///
/// Uses the same definition as every other remaining figure:
/// [BudgetCalculationService.calculateRemainingBudget] over the SQL period
/// total. Budgets already correct are not written.
class RecalculateRemainingAmountsUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  RecalculateRemainingAmountsUseCase({
    required this.repository,
    required this.calculationService,
  });

  /// Returns the number of budgets whose stored remaining amount changed.
  Future<int> call() async {
    var updated = 0;
    for (final budget in await repository.getAllBudgets()) {
      final statistics = await repository.getBudgetStatistics(budget.id);
      final remaining = calculationService.calculateRemainingBudget(
        monthlyAmount: budget.monthlyAmount,
        totalSpent: statistics.totalSpent,
      );
      if (remaining == budget.remainingAmount) continue;
      // In a transaction, so an edit saved meanwhile cannot be overwritten
      // by the row this read.
      await repository.transaction(
        () => repository.updateBudgetRemainingAmount(budget.id),
      );
      updated++;
    }
    return updated;
  }
}
