import '../../../../core/currency/money_math.dart';
import '../entities/budget_error.dart';
import '../entities/budget_list_summary_entity.dart';
import '../entities/budget_filter.dart';
import '../repository/budget_repository.dart';

/// Returns combined summary metrics across all active budgets.
class GetBudgetListSummaryUseCase {
  final BudgetRepository repository;

  GetBudgetListSummaryUseCase({required this.repository});

  Future<BudgetResult<BudgetListSummaryEntity>> call() async {
    try {
      // Get all non-archived budgets
      final budgets = await repository.getAllBudgets(
        options: const BudgetQueryOptions(filter: BudgetFilter.active),
      );

      if (budgets.isEmpty) {
        return const BudgetSuccess(BudgetListSummaryEntity.empty);
      }

      // Filter to active budgets (not archived and currently within date range)
      final activeBudgets = budgets.where((budget) {
        return budget.isActive;
      }).toList();

      if (activeBudgets.isEmpty) {
        return const BudgetSuccess(BudgetListSummaryEntity.empty);
      }

      // One total per currency, never added across currencies, each summed
      // in integer units so the total is exact.
      final amountsByCurrency = <String, List<double>>{};
      for (final budget in activeBudgets) {
        (amountsByCurrency[budget.currency] ??= []).add(budget.remainingAmount);
      }

      return BudgetSuccess(
        BudgetListSummaryEntity(
          remainingByCurrency: amountsByCurrency.map((code, amounts) {
            final money = MoneyMath.forCurrency(code);
            return MapEntry(code, money.toAmount(money.sumUnits(amounts)));
          }),
          activeBudgetCount: activeBudgets.length,
        ),
      );
    } catch (e) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidBudget,
          message: 'Failed to calculate budget list summary: ${e.toString()}',
        ),
      );
    }
  }
}
