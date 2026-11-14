import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_day_targets_usecase.dart';

import 'get_spending_targets_usecase_test.dart' show FakeBudgetRepository;
import '../../../../helpers/safe_to_spend_fakes.dart';

/// Spending per day, as the database would sum it.
class _DailyRepository extends SafeSpendFakeDashboardRepository {
  final Map<DateTime, double> daily;
  _DailyRepository(this.daily);

  @override
  Future<Map<DateTime, double>> getDailyDiscretionarySpending({
    required String budgetId,
    required DateTime start,
    required DateTime end,
  }) async => daily;
}

void main() {
  final today = DateTime(2026, 8, 10);
  late FakeBudgetRepository budgets;

  BudgetEntity budget({DateTime? start, DateTime? end}) => BudgetEntity(
    id: 'aug',
    name: 'August',
    monthlyAmount: 31000,
    remainingAmount: 31000,
    currency: 'INR',
    startDate: start ?? DateTime(2026, 8, 1),
    endDate: end ?? DateTime(2026, 8, 31),
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );

  GetDayTargetsUseCase useCase(Map<DateTime, double> daily) {
    final dashboard = _DailyRepository(daily);
    return GetDayTargetsUseCase(
      safeToSpend: fakeSafeToSpendUseCase(
        budgets,
        dashboardRepository: dashboard,
        clock: () => today,
      ),
      repository: dashboard,
      calculator: SafeToSpendCalculator(BudgetCalculationService()),
    );
  }

  setUp(() => budgets = FakeBudgetRepository());

  test('one target per day of a running budget, keyed by date', () async {
    budgets.budgets = [budget()];
    final targets = await useCase({})('aug', referenceDate: today);

    expect(targets.keys, [for (var d = 1; d <= 10; d++) DateTime(2026, 8, d)]);
    // Nothing spent: 31,000 ÷ 31 on day 1 … and ÷ 22 on day 10 (the same
    // 31,000 left), the engine's figure.
    expect(targets[DateTime(2026, 8, 1)]!.target, closeTo(1000, 1e-9));
    expect(targets[DateTime(2026, 8, 10)]!.target, closeTo(31000 / 22, 1e-9));
  });

  test('a day with spending carries it and its result', () async {
    budgets.budgets = [budget()];
    final targets = await useCase({DateTime(2026, 8, 3, 14): 1500})(
      'aug',
      referenceDate: today,
    );
    final day = targets[DateTime(2026, 8, 3)]!;
    expect(day.spent, 1500);
    expect(day.result, closeTo(day.target - 1500, 1e-9));
  });

  test('nothing for a budget that is not running', () async {
    budgets.budgets = [
      budget(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)),
    ];
    expect(await useCase({})('aug', referenceDate: today), isEmpty);
  });

  test('nothing for a budget that does not exist', () async {
    budgets.budgets = [];
    expect(await useCase({})('aug', referenceDate: today), isEmpty);
  });
}
