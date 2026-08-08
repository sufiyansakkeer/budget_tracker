import '../entities/budget_analytics_entity.dart';
import '../entities/budget_calculation_input.dart';
import '../entities/budget_error.dart';
import '../repository/budget_repository.dart';
import '../services/budget_calculation_service.dart';

/// Loads extended budget analytics for reports and insights.
class GetBudgetAnalyticsUseCase {
  final BudgetRepository repository;
  final BudgetCalculationService calculationService;

  GetBudgetAnalyticsUseCase({
    required this.repository,
    required this.calculationService,
  });

  Future<BudgetResult<BudgetAnalyticsEntity>> call({
    required String budgetId,
    DateTime? referenceDate,
  }) async {
    final contextResult = await repository.getCalculationContext(
      budgetId,
      referenceDate: referenceDate,
    );

    return switch (contextResult) {
      BudgetError(:final failure) => BudgetError(failure),
      BudgetSuccess(:final data) => _buildAnalytics(data),
    };
  }

  BudgetResult<BudgetAnalyticsEntity> _buildAnalytics(
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

      final analytics = calculationService.buildAnalytics(input);
      return BudgetSuccess(analytics);
    } on ArgumentError catch (e) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidDate,
          message: e.message?.toString() ?? 'Invalid date for analytics',
        ),
      );
    }
  }
}
