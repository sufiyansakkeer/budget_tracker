import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/entities/safe_to_spend/day_target.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/services/safe_to_spend_calculator.dart';
import '../repository/dashboard_repository.dart';
import 'get_safe_to_spend_usecase.dart';

/// Each day's target for a running budget, from its first day to today,
/// keyed by date (time of day zero), for Activity's day headers. Empty when
/// the budget is not running or its figures can't be worked out.
///
/// The series is [SafeToSpendCalculator.targetSeries]: past days use
/// today's set-asides, and today's entry equals Home's amount.
class GetDayTargetsUseCase {
  final GetSafeToSpendUseCase safeToSpend;
  final DashboardRepository repository;
  final SafeToSpendCalculator calculator;

  const GetDayTargetsUseCase({
    required this.safeToSpend,
    required this.repository,
    required this.calculator,
  });

  Future<Map<DateTime, DayTarget>> call(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    final result = await safeToSpend(
      budgetId: budgetId,
      referenceDate: referenceDate,
    );
    if (result is! BudgetSuccess<SafeToSpendEntity>) return const {};
    final today = result.data;
    if (!today.isRunning) return const {};
    final daily = await repository.getDailyDiscretionarySpending(
      budgetId: budgetId,
      start: today.startDate,
      end: today.today,
    );
    return {
      for (final day in calculator.targetSeries(today, daily)) day.date: day,
    };
  }
}
