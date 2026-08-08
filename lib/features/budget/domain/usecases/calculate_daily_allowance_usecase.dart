import '../entities/budget_error.dart';
import '../repository/budget_repository.dart';
import '../services/budget_calculation_service.dart';

/// Calculates the daily safe spending allowance for the current budget.
class CalculateDailyAllowanceUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  CalculateDailyAllowanceUseCase({
    required this.repository,
    required this.calculationService,
  });

  Future<BudgetResult<double>> call({
    required String budgetId,
    DateTime? referenceDate,
  }) async {
    final contextResult = await repository.getCalculationContext(
      budgetId,
      referenceDate: referenceDate,
    );

    return switch (contextResult) {
      BudgetError(:final failure) => BudgetError(failure),
      BudgetSuccess(:final data) => _calculate(data),
    };
  }

  BudgetResult<double> _calculate(BudgetCalculationContext context) {
    if (context.budget.monthlyAmount <= 0) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidBudget,
          message: 'Budget amount must be greater than zero',
        ),
      );
    }

    try {
      final remainingBudget = calculationService.calculateRemainingBudget(
        monthlyAmount: context.budget.monthlyAmount,
        totalSpent: context.statistics.totalSpent,
      );
      final remainingDays = calculationService.calculateRemainingDays(
        referenceDate: context.referenceDate,
        startDate: context.budget.startDate,
        endDate: context.budget.endDate,
      );

      final allowance = calculationService.calculateDailyAllowance(
        remainingBudget: remainingBudget,
        remainingDays: remainingDays,
      );

      return BudgetSuccess(allowance);
    } on ArgumentError catch (e) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidDate,
          message: e.message?.toString() ?? 'Invalid date for daily allowance',
        ),
      );
    }
  }
}
