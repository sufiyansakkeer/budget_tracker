import '../entities/budget_error.dart';
import '../entities/budget_status.dart';
import '../repository/budget_repository.dart';
import '../services/budget_calculation_service.dart';

/// Returns the current budget health status based on spending utilization.
class GetBudgetStatusUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  GetBudgetStatusUseCase({
    required this.repository,
    required this.calculationService,
  });

  Future<BudgetResult<BudgetStatus>> call({DateTime? referenceDate}) async {
    final contextResult = await repository.getCalculationContext(
      referenceDate: referenceDate,
    );

    return switch (contextResult) {
      BudgetError(:final failure) => BudgetError(failure),
      BudgetSuccess(:final data) => _calculateStatus(data),
    };
  }

  BudgetResult<BudgetStatus> _calculateStatus(BudgetCalculationContext context) {
    if (context.budget.monthlyAmount <= 0) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidBudget,
          message: 'Monthly budget must be greater than zero',
        ),
      );
    }

    try {
      final utilization = calculationService.calculateBudgetUtilization(
        totalSpent: context.statistics.totalSpent,
        monthlyAmount: context.budget.monthlyAmount,
      );

      final status = calculationService.calculateBudgetStatus(
        budgetUtilization: utilization,
      );

      return BudgetSuccess(status);
    } on ArgumentError catch (e) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidDate,
          message: e.message?.toString() ?? 'Invalid date for status calculation',
        ),
      );
    }
  }
}
