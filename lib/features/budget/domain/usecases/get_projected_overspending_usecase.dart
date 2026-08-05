import '../entities/budget_error.dart';
import '../repository/budget_repository.dart';
import '../services/budget_calculation_service.dart';

/// Returns projected overspending at month-end based on current spending pace.
class GetProjectedOverspendingUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  GetProjectedOverspendingUseCase({
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
      final daysPassed = calculationService.calculateDaysPassed(
        referenceDate: context.referenceDate,
        budgetMonth: context.budget.month,
        budgetYear: context.budget.year,
      );
      final averageDaily = calculationService.calculateAverageDailySpending(
        totalSpent: context.statistics.totalSpent,
        daysPassed: daysPassed,
      );
      final monthDays = calculationService.daysInMonth(
        context.budget.month,
        context.budget.year,
      );
      final projected = calculationService.calculateExpectedMonthEndSpending(
        averageDailySpending: averageDaily,
        daysInMonth: monthDays,
      );

      final overspending = calculationService.calculateProjectedOverspending(
        monthlyAmount: context.budget.monthlyAmount,
        expectedMonthEndSpending: projected,
      );

      return BudgetSuccess(overspending);
    } on ArgumentError catch (e) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidDate,
          message: e.message?.toString() ?? 'Invalid date for overspending projection',
        ),
      );
    }
  }
}
