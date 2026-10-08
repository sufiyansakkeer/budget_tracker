import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../entities/spending_pace.dart';
import '../repository/dashboard_repository.dart';
import '../services/spending_pace_builder.dart';

/// Reads a running budget's discretionary spending per day and builds its
/// [SpendingPace]. Returns `null` when the budget is not running today.
class GetSpendingPaceUseCase {
  final DashboardRepository repository;

  const GetSpendingPaceUseCase({required this.repository});

  Future<SpendingPace?> call(SafeToSpendEntity safeToSpend) async {
    if (!safeToSpend.isRunning) return null;
    final daily = await repository.getDailyDiscretionarySpending(
      budgetId: safeToSpend.budgetId,
      start: safeToSpend.startDate,
      end: safeToSpend.today,
    );
    return SpendingPaceBuilder.build(
      safeToSpend: safeToSpend,
      dailyDiscretionary: daily,
    );
  }
}
