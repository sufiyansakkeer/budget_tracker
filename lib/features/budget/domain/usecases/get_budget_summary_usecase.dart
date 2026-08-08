import '../entities/budget_calculation_input.dart';
import '../entities/budget_error.dart';
import '../entities/budget_summary_entity.dart';
import '../repository/budget_repository.dart';
import '../services/budget_calculation_service.dart';

/// Loads a complete budget summary by fetching data and delegating calculations.
class GetBudgetSummaryUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  GetBudgetSummaryUseCase({
    required this.repository,
    required this.calculationService,
  });

  Future<BudgetResult<BudgetSummaryEntity>> call({
    required String budgetId,
    DateTime? referenceDate,
  }) async {
    final contextResult = await repository.getCalculationContext(
      budgetId,
      referenceDate: referenceDate,
    );

    return switch (contextResult) {
      BudgetError(:final failure) => BudgetError(failure),
      BudgetSuccess(:final data) => _buildSummary(data),
    };
  }

  BudgetResult<BudgetSummaryEntity> _buildSummary(
    BudgetCalculationContext context,
  ) {
    if (context.budget.monthlyAmount <= 0) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidBudget,
          message: 'Budget amount must be greater than zero',
        ),
      );
    }

    try {
      final input = BudgetCalculationInput(
        monthlyAmount: context.budget.monthlyAmount,
        totalSpent: context.statistics.totalSpent,
        todaySpending: context.statistics.todaySpending,
        referenceDate: context.referenceDate,
        startDate: context.budget.startDate,
        endDate: context.budget.endDate,
      );

      final summary = calculationService.buildSummary(
        input,
        currency: context.budget.currency,
      );

      return BudgetSuccess(summary);
    } on ArgumentError catch (e) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidDate,
          message:
              e.message?.toString() ?? 'Invalid date for budget calculation',
        ),
      );
    }
  }
}
