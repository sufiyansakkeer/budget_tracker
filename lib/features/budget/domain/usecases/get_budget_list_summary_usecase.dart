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
        return const BudgetSuccess(
          BudgetListSummaryEntity(
            totalRemaining: 0,
            activeBudgetCount: 0,
            currency: '',
          ),
        );
      }

      // Filter to non-archived budgets (include all, regardless of date range)
      final activeBudgets = budgets.where((budget) {
        return !budget.isArchived;
      }).toList();

      if (activeBudgets.isEmpty) {
        return const BudgetSuccess(
          BudgetListSummaryEntity(
            totalRemaining: 0,
            activeBudgetCount: 0,
            currency: '',
          ),
        );
      }

      // Validate all active budgets use the same currency
      final firstCurrency = activeBudgets.first.currency;
      final allSameCurrency = activeBudgets.every(
        (b) => b.currency == firstCurrency,
      );

      if (!allSameCurrency) {
        return const BudgetError(
          BudgetFailure(
            type: BudgetErrorType.invalidBudget,
            message: 'Cannot combine budgets with different currencies',
          ),
        );
      }

      // Sum remaining amounts
      final totalRemaining = activeBudgets.fold<double>(
        0.0,
        (sum, budget) => sum + budget.remainingAmount,
      );

      return BudgetSuccess(
        BudgetListSummaryEntity(
          totalRemaining: totalRemaining,
          activeBudgetCount: activeBudgets.length,
          currency: firstCurrency,
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
