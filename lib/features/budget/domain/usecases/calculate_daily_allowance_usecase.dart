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

  Future<BudgetResult<double>> call({DateTime? referenceDate}) async {
    final contextResult = await repository.getCalculationContext(
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
          message: 'Monthly budget must be greater than zero',
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
        budgetMonth: context.budget.month,
        budgetYear: context.budget.year,
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
