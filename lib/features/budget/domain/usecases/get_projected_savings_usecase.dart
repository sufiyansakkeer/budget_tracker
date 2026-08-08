import '../entities/budget_error.dart';
import '../repository/budget_repository.dart';
import '../services/budget_calculation_service.dart';

/// Returns projected savings at month-end based on current spending pace.
class GetProjectedSavingsUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  GetProjectedSavingsUseCase({
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
      final daysPassed = calculationService.calculateDaysPassed(
        referenceDate: context.referenceDate,
        startDate: context.budget.startDate,
        endDate: context.budget.endDate,
      );
      final averageDaily = calculationService.calculateAverageDailySpending(
        totalSpent: context.statistics.totalSpent,
        daysPassed: daysPassed,
      );
      final periodDays = calculationService.daysInPeriod(
        startDate: context.budget.startDate,
        endDate: context.budget.endDate,
      );
      final projected = calculationService.calculateExpectedPeriodEndSpending(
        averageDailySpending: averageDaily,
        daysInPeriod: periodDays,
      );

      final savings = calculationService.calculateProjectedSavings(
        monthlyAmount: context.budget.monthlyAmount,
        expectedPeriodEndSpending: projected,
      );

      return BudgetSuccess(savings);
    } on ArgumentError catch (e) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidDate,
          message:
              e.message?.toString() ?? 'Invalid date for savings projection',
        ),
      );
    }
  }
}
