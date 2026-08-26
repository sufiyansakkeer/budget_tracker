import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_status.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBudgetRepository implements BudgetRepository {
  BudgetEntity? budget;
  List<BudgetEntity> budgets = [];
  double todaySpending = 0.0;
  double weekSpending = 0.0;
  MonthlyStatisticsEntity statistics = MonthlyStatisticsEntity.empty;

  @override
  Future<BudgetEntity?> getActiveBudget() async => budget;

  @override
  Future<String?> getActiveBudgetId() async => budget?.id;

  @override
  Future<void> setActiveBudgetId(String budgetId) async {}

  @override
  Future<BudgetEntity?> getBudgetById(String id) async => budget;

  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async {
    if (budgets.isNotEmpty) {
      if (options?.filter == BudgetFilter.active) {
        return budgets.where((b) => !b.isArchived).toList();
      }
      return budgets;
    }
    return budget == null ? <BudgetEntity>[] : [budget!];
  }

  @override
  Future<BudgetEntity> createBudget(BudgetEntity budget) async => budget;

  @override
  Future<BudgetEntity> updateBudget(BudgetEntity budget) async => budget;

  @override
  Future<void> deleteBudget(String id) async {}

  @override
  Future<BudgetEntity> setBudgetArchived(
    String id, {
    required bool archived,
  }) async {
    final b = budget;
    if (b == null) throw StateError('No budget');
    budget = b.copyWith(isArchived: archived);
    return budget!;
  }

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async => budget!;

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => statistics;

  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async => todaySpending;

  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 1;

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    if (budget == null) {
      return const BudgetError(
        BudgetFailure(type: BudgetErrorType.notFound, message: 'No budget'),
      );
    }
    return BudgetSuccess(
      BudgetCalculationContext(
        budget: budget!,
        statistics: statistics,
        referenceDate: referenceDate ?? DateTime(2026, 8, 10),
      ),
    );
  }

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}

  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => weekSpending;
}

void main() {
  late FakeBudgetRepository repository;
  late BudgetCalculationService calculationService;
  late GetSpendingTargetsUseCase useCase;

  setUp(() {
    repository = FakeBudgetRepository();
    calculationService = BudgetCalculationService();
    useCase = GetSpendingTargetsUseCase(
      repository: repository,
      calculationService: calculationService,
    );
  });

  group('No active budget', () {
    test(
      'returns PerBudgetSpendingTargetNoBudget when no budgets exist',
      () async {
        repository.budgets = [];
        final result = await useCase.callPerBudget(
          referenceDate: DateTime(2026, 8, 10),
        );
        expect(result, isA<PerBudgetSpendingTargetNoBudget>());
      },
    );

    test(
      'returns PerBudgetSpendingTargetNoBudget when all budgets archived',
      () async {
        repository.budgets = [
          BudgetEntity(
            id: 'b1',
            name: 'Archived',
            monthlyAmount: 30000,
            remainingAmount: 10000,
            currency: 'INR',
            startDate: DateTime(2026, 7, 1),
            endDate: DateTime(2026, 7, 31),
            isArchived: true,
            createdAt: DateTime(2026, 7, 1),
            updatedAt: DateTime(2026, 7, 1),
          ),
        ];
        final result = await useCase.callPerBudget(
          referenceDate: DateTime(2026, 8, 10),
        );
        expect(result, isA<PerBudgetSpendingTargetNoBudget>());
      },
    );
  });

  group('Daily limit', () {
    test(
      'single 30k budget on day 10 of 31-day period with no spending',
      () async {
        repository.budgets = [
          BudgetEntity(
            id: 'b1',
            name: 'Personal',
            monthlyAmount: 30000,
            remainingAmount: 30000,
            currency: 'INR',
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 8, 31),
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
        ];
        repository.todaySpending = 0;
        repository.weekSpending = 0;

        final result =
            await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 10))
                as PerBudgetSpendingTargetSuccess;

        expect(result.budgetLimits, hasLength(1));
        final bl = result.budgetLimits.first;

        // remainingBudget = 30000, remainingDays = 22
        // dailyLimit = 30000/22 ≈ 1363.64
        expect(bl.dailyLimit, closeTo(1363.64, 0.01));
        expect(bl.spentToday, 0);
        expect(bl.remainingToday, closeTo(1363.64, 0.01));
        expect(bl.exceededToday, 0);
        expect(bl.status, SpendingTargetStatus.onTrack);
        expect(bl.currency, 'INR');
        expect(result.currency, 'INR');
        expect(result.combinedDailyTarget, closeTo(1363.64, 0.01));
      },
    );

    test('daily limit with spending shows correct remaining', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Personal',
          monthlyAmount: 30000,
          remainingAmount: 29200,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 800;
      repository.weekSpending = 3000;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 10))
              as PerBudgetSpendingTargetSuccess;

      final bl = result.budgetLimits.first;

      // remainingBudget = 29200, remainingDays = 22
      // dailyLimit = 29200/22 ≈ 1327.27
      expect(bl.dailyLimit, closeTo(1327.27, 0.01));
      expect(bl.spentToday, 800);
      expect(bl.remainingToday, closeTo(527.27, 0.01));
      expect(bl.status, SpendingTargetStatus.onTrack);
    });

    test('exceeded limit shows exceeded amount', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Personal',
          monthlyAmount: 30000,
          remainingAmount: 28500,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 1700;
      repository.weekSpending = 5000;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 10))
              as PerBudgetSpendingTargetSuccess;

      final bl = result.budgetLimits.first;

      // remainingBudget = 28500, remainingDays = 22
      // dailyLimit = 28500/22 ≈ 1295.45
      expect(bl.dailyLimit, closeTo(1295.45, 0.01));
      expect(bl.spentToday, 1700);
      expect(bl.remainingToday, 0);
      expect(bl.exceededToday, closeTo(404.55, 0.01));
      expect(bl.status, SpendingTargetStatus.exceeded);
    });

    test('near limit status at 80-100%', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Personal',
          monthlyAmount: 30000,
          remainingAmount: 28500,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      // dailyLimit ≈ 1295, 90% = 1166
      repository.todaySpending = 1166;
      repository.weekSpending = 3000;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 10))
              as PerBudgetSpendingTargetSuccess;

      expect(result.budgetLimits.first.status, SpendingTargetStatus.nearLimit);
    });
  });

  group('Weekly target', () {
    test('single budget provides proportional weekly target', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Personal',
          monthlyAmount: 30000,
          remainingAmount: 30000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 0;
      repository.weekSpending = 3000;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 11))
              as PerBudgetSpendingTargetSuccess;

      final bl = result.budgetLimits.first;

      // Monday Aug 11 → week Aug 11-17
      // Budget covers all 7 days
      // weeklyTarget = 30000 * 7 / 31 ≈ 6774.19
      expect(bl.weeklyTarget, closeTo(6774.19, 0.01));
      expect(bl.weeklySpent, 3000);
      expect(bl.weeklyRemaining, closeTo(3774.19, 0.01));
      expect(bl.weeklyStatus, SpendingTargetStatus.onTrack);
    });

    test('partial week at budget start', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Short',
          monthlyAmount: 10000,
          remainingAmount: 10000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 13),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 13),
          updatedAt: DateTime(2026, 8, 13),
        ),
      ];
      repository.todaySpending = 0;
      repository.weekSpending = 0;

      // Wednesday Aug 13 → week Mon Aug 11 - Sun Aug 17, budget starts Aug 13
      // effective week: Aug 13 → Aug 17 (inclusive), daysThisWeek = 4
      // totalBudgetDays = 31 - 13 + 1 = 19
      // weeklyTarget = 10000 * 4 / 19 ≈ 2105.26
      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 13))
              as PerBudgetSpendingTargetSuccess;
      expect(result.budgetLimits.first.weeklyTarget, closeTo(2105.26, 0.01));
    });

    test('partial week at budget end', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Short',
          monthlyAmount: 10000,
          remainingAmount: 5000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 15),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 0;
      repository.weekSpending = 0;

      // Thursday Aug 14 → week Mon Aug 11 - Sun Aug 17, budget ends Aug 15
      // effectiveWeekEnd is clamped to budget.endDate
      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 14))
              as PerBudgetSpendingTargetSuccess;
      // Verify the weekly target is proportional to the budget period
      expect(result.budgetLimits.first.weeklyTarget, greaterThan(0));
      expect(result.budgetLimits.first.weeklyTarget, lessThanOrEqualTo(10000));
    });
  });

  group('Multiple budgets', () {
    test('combines targets from multiple active budgets', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'food',
          name: 'Food',
          monthlyAmount: 6000,
          remainingAmount: 4000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
        BudgetEntity(
          id: 'travel',
          name: 'Travel',
          monthlyAmount: 5000,
          remainingAmount: 3000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 0;
      repository.weekSpending = 0;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 10))
              as PerBudgetSpendingTargetSuccess;

      expect(result.budgetLimits, hasLength(2));

      // Food: 4000/22 ≈ 181.82, Travel: 3000/22 ≈ 136.36
      // Combined dailyTarget ≈ 318.18
      expect(result.combinedDailyTarget, closeTo(318.18, 0.01));

      final food = result.budgetLimits.firstWhere(
        (bl) => bl.budgetId == 'food',
      );
      final travel = result.budgetLimits.firstWhere(
        (bl) => bl.budgetId == 'travel',
      );
      expect(food.dailyLimit, closeTo(181.82, 0.01));
      expect(travel.dailyLimit, closeTo(136.36, 0.01));
    });

    test('budget not active today is excluded', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'active',
          name: 'Active',
          monthlyAmount: 30000,
          remainingAmount: 30000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
        BudgetEntity(
          id: 'future',
          name: 'Future',
          monthlyAmount: 20000,
          remainingAmount: 20000,
          currency: 'INR',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 0;
      repository.weekSpending = 0;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 10))
              as PerBudgetSpendingTargetSuccess;

      // Only the active budget contributes
      expect(result.budgetLimits, hasLength(1));
      expect(result.budgetLimits.first.budgetId, 'active');
      expect(result.budgetLimits.first.dailyLimit, closeTo(30000 / 22, 0.01));
    });
  });

  group('Date edge cases', () {
    test('first day of budget period', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Personal',
          monthlyAmount: 30000,
          remainingAmount: 30000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 0;
      repository.weekSpending = 0;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 1))
              as PerBudgetSpendingTargetSuccess;

      // Day 1, remainingDays = 31
      expect(result.budgetLimits.first.dailyLimit, closeTo(30000 / 31, 0.01));
    });

    test('last day of budget period', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Personal',
          monthlyAmount: 30000,
          remainingAmount: 5000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 0;
      repository.weekSpending = 0;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 31))
              as PerBudgetSpendingTargetSuccess;

      // Last day, remainingDays = 1
      expect(result.budgetLimits.first.dailyLimit, 5000);
    });
  });

  group('Budget expired', () {
    test('returns no budget when all budgets have ended', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Expired',
          monthlyAmount: 30000,
          remainingAmount: 10000,
          currency: 'INR',
          startDate: DateTime(2026, 7, 1),
          endDate: DateTime(2026, 7, 31),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
      ];

      final result = await useCase.callPerBudget(
        referenceDate: DateTime(2026, 8, 10),
      );
      expect(result, isA<PerBudgetSpendingTargetNoBudget>());
    });
  });

  group('Progress calculations', () {
    test('progress caps at 1.0 for exceeded limit', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Personal',
          monthlyAmount: 30000,
          remainingAmount: 28500,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 1700; // Exceeds limit
      repository.weekSpending = 10000;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 10))
              as PerBudgetSpendingTargetSuccess;

      final bl = result.budgetLimits.first;
      // Progress should be capped at 1.0 for visual display
      expect(bl.progress, lessThanOrEqualTo(1.0));
      expect(bl.progress, greaterThan(0));
    });

    test('progress is 0 when nothing spent', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'Personal',
          monthlyAmount: 30000,
          remainingAmount: 30000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 0;
      repository.weekSpending = 0;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 10))
              as PerBudgetSpendingTargetSuccess;

      expect(result.budgetLimits.first.progress, 0.0);
      expect(result.budgetLimits.first.weeklyProgress, 0.0);
    });
  });

  group('Currency', () {
    test('uses the active budget currency', () async {
      repository.budgets = [
        BudgetEntity(
          id: 'b1',
          name: 'USD Budget',
          monthlyAmount: 1000,
          remainingAmount: 1000,
          currency: 'USD',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];
      repository.todaySpending = 0;
      repository.weekSpending = 0;

      final result =
          await useCase.callPerBudget(referenceDate: DateTime(2026, 8, 10))
              as PerBudgetSpendingTargetSuccess;

      expect(result.currency, 'USD');
      expect(result.budgetLimits.first.currency, 'USD');
    });
  });
}
