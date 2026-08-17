import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';

import 'package:monivo/features/budget/domain/entities/budget_list_summary_entity.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_list_summary_usecase.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';

@GenerateMocks([BudgetRepository])
import 'get_budget_list_summary_usecase_test.mocks.dart';

void main() {
  late GetBudgetListSummaryUseCase useCase;
  late MockBudgetRepository mockRepository;

  setUp(() {
    mockRepository = MockBudgetRepository();
    useCase = GetBudgetListSummaryUseCase(repository: mockRepository);
  });

  group('GetBudgetListSummaryUseCase', () {
    final now = DateTime(2026, 8, 11);
    final startDate = DateTime(2026, 8, 1);
    final endDate = DateTime(2026, 8, 31);

    test('returns empty summary when no budgets exist', () async {
      when(
        mockRepository.getAllBudgets(options: anyNamed('options')),
      ).thenAnswer((_) async => []);

      final result = await useCase();

      expect(result, isA<BudgetSuccess<BudgetListSummaryEntity>>());
      final summary = (result as BudgetSuccess).data;
      expect(summary.totalRemaining, 0);
      expect(summary.activeBudgetCount, 0);
      expect(summary.currency, '');
    });

    test('returns empty summary when no active budgets exist', () async {
      final archivedBudget = BudgetEntity(
        id: '1',
        name: 'Archived Budget',
        monthlyAmount: 10000,
        remainingAmount: 5000,
        currency: 'INR',
        startDate: startDate,
        endDate: endDate,
        isArchived: true,
        createdAt: now,
        updatedAt: now,
      );

      when(
        mockRepository.getAllBudgets(options: anyNamed('options')),
      ).thenAnswer((_) async => [archivedBudget]);

      final result = await useCase();

      expect(result, isA<BudgetSuccess<BudgetListSummaryEntity>>());
      final summary = (result as BudgetSuccess).data;
      expect(summary.totalRemaining, 0);
      expect(summary.activeBudgetCount, 0);
    });

    test('calculates combined remaining for single active budget', () async {
      final budget = BudgetEntity(
        id: '1',
        name: 'Food Budget',
        monthlyAmount: 10000,
        remainingAmount: 3500,
        currency: 'INR',
        startDate: startDate,
        endDate: endDate,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      when(
        mockRepository.getAllBudgets(options: anyNamed('options')),
      ).thenAnswer((_) async => [budget]);

      final result = await useCase();

      expect(result, isA<BudgetSuccess<BudgetListSummaryEntity>>());
      final summary = (result as BudgetSuccess).data;
      expect(summary.totalRemaining, 3500);
      expect(summary.activeBudgetCount, 1);
      expect(summary.currency, 'INR');
    });

    test('calculates combined remaining for multiple active budgets', () async {
      final budget1 = BudgetEntity(
        id: '1',
        name: 'Food Budget',
        monthlyAmount: 10000,
        remainingAmount: 4000,
        currency: 'INR',
        startDate: startDate,
        endDate: endDate,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      final budget2 = BudgetEntity(
        id: '2',
        name: 'Travel Budget',
        monthlyAmount: 20000,
        remainingAmount: 12000,
        currency: 'INR',
        startDate: startDate,
        endDate: endDate,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      final budget3 = BudgetEntity(
        id: '3',
        name: 'Shopping Budget',
        monthlyAmount: 5000,
        remainingAmount: 2500,
        currency: 'INR',
        startDate: startDate,
        endDate: endDate,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      when(
        mockRepository.getAllBudgets(options: anyNamed('options')),
      ).thenAnswer((_) async => [budget1, budget2, budget3]);

      final result = await useCase();

      expect(result, isA<BudgetSuccess<BudgetListSummaryEntity>>());
      final summary = (result as BudgetSuccess).data;
      expect(summary.totalRemaining, 18500); // 4000 + 12000 + 2500
      expect(summary.activeBudgetCount, 3);
      expect(summary.currency, 'INR');
    });

    test('excludes budgets outside date range', () async {
      final activeBudget = BudgetEntity(
        id: '1',
        name: 'Active Budget',
        monthlyAmount: 10000,
        remainingAmount: 5000,
        currency: 'INR',
        startDate: startDate,
        endDate: endDate,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      final expiredBudget = BudgetEntity(
        id: '2',
        name: 'Expired Budget',
        monthlyAmount: 10000,
        remainingAmount: 8000,
        currency: 'INR',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 31),
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      when(
        mockRepository.getAllBudgets(options: anyNamed('options')),
      ).thenAnswer((_) async => [activeBudget, expiredBudget]);

      final result = await useCase();

      expect(result, isA<BudgetSuccess<BudgetListSummaryEntity>>());
      final summary = (result as BudgetSuccess).data;
      expect(summary.totalRemaining, 5000); // Only active budget
      expect(summary.activeBudgetCount, 1);
    });

    test(
      'combines budgets with different currencies using first active currency fallback',
      () async {
        final budget1 = BudgetEntity(
          id: '1',
          name: 'INR Budget',
          monthlyAmount: 10000,
          remainingAmount: 5000,
          currency: 'INR',
          startDate: startDate,
          endDate: endDate,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );

        final budget2 = BudgetEntity(
          id: '2',
          name: 'USD Budget',
          monthlyAmount: 1000,
          remainingAmount: 500,
          currency: 'USD',
          startDate: startDate,
          endDate: endDate,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );

        when(
          mockRepository.getAllBudgets(options: anyNamed('options')),
        ).thenAnswer((_) async => [budget1, budget2]);

        final result = await useCase();

        expect(result, isA<BudgetSuccess<BudgetListSummaryEntity>>());
        final data = (result as BudgetSuccess).data;
        expect(data.totalRemaining, 5500);
        expect(data.activeBudgetCount, 2);
        expect(data.currency, 'INR');
      },
    );

    test('handles negative remaining amounts (overspent budgets)', () async {
      final budget1 = BudgetEntity(
        id: '1',
        name: 'Budget 1',
        monthlyAmount: 10000,
        remainingAmount: 3000,
        currency: 'INR',
        startDate: startDate,
        endDate: endDate,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      final budget2 = BudgetEntity(
        id: '2',
        name: 'Overspent Budget',
        monthlyAmount: 5000,
        remainingAmount: -1000, // Overspent by 1000
        currency: 'INR',
        startDate: startDate,
        endDate: endDate,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      when(
        mockRepository.getAllBudgets(options: anyNamed('options')),
      ).thenAnswer((_) async => [budget1, budget2]);

      final result = await useCase();

      expect(result, isA<BudgetSuccess<BudgetListSummaryEntity>>());
      final summary = (result as BudgetSuccess).data;
      expect(summary.totalRemaining, 2000); // 3000 + (-1000)
      expect(summary.activeBudgetCount, 2);
    });

    test('handles zero remaining amounts', () async {
      final budget = BudgetEntity(
        id: '1',
        name: 'Depleted Budget',
        monthlyAmount: 10000,
        remainingAmount: 0,
        currency: 'INR',
        startDate: startDate,
        endDate: endDate,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      when(
        mockRepository.getAllBudgets(options: anyNamed('options')),
      ).thenAnswer((_) async => [budget]);

      final result = await useCase();

      expect(result, isA<BudgetSuccess<BudgetListSummaryEntity>>());
      final summary = (result as BudgetSuccess).data;
      expect(summary.totalRemaining, 0);
      expect(summary.activeBudgetCount, 1);
    });
  });
}
