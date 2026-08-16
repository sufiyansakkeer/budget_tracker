import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/core/domain/entities/budget_entity.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_calculation_input.dart';

import 'package:budget_tracker/features/budget/domain/services/budget_calculation_service.dart';

void main() {
  late BudgetCalculationService calculationService;

  setUp(() {
    calculationService = BudgetCalculationService();
  });

  group('Smart Budget Tracker fixes unit tests', () {
    test('Test 1 – Single Budget remaining and progress', () {
      final input = BudgetCalculationInput(
        monthlyAmount: 10000,
        totalSpent: 4000,
        todaySpending: 0,
        referenceDate: DateTime(2026, 8, 10),
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );

      final summary = calculationService.buildSummary(input, currency: '₹');

      expect(summary.remainingBudget, 6000);
      expect(summary.budgetUtilization, 0.40);
    });

    test('Test 2 & 3 – Multiple Budgets sum remaining amount', () {
      final budgets = [
        BudgetEntity(
          id: '1',
          name: 'Budget A',
          monthlyAmount: 10000,
          remainingAmount: 6000,
          currency: '₹',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        BudgetEntity(
          id: '2',
          name: 'Budget B',
          monthlyAmount: 20000,
          remainingAmount: 15000,
          currency: '₹',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        BudgetEntity(
          id: '3',
          name: 'Budget C',
          monthlyAmount: 5000,
          remainingAmount: 3000,
          currency: '₹',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final totalRemaining = budgets.fold<double>(
        0.0,
        (sum, b) => sum + b.remainingAmount,
      );

      expect(totalRemaining, 24000);
    });

    test('Test 4 & 5 – Budget progress normal and overrun', () {
      // Normal Progress
      final inputNormal = BudgetCalculationInput(
        monthlyAmount: 10000,
        totalSpent: 6000,
        todaySpending: 0,
        referenceDate: DateTime(2026, 8, 10),
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );
      final summaryNormal = calculationService.buildSummary(
        inputNormal,
        currency: '₹',
      );
      expect(summaryNormal.budgetUtilization, 0.60);
      expect(summaryNormal.budgetUtilization.clamp(0.0, 1.0), 0.60);

      // Overrun Progress
      final inputOverrun = BudgetCalculationInput(
        monthlyAmount: 10000,
        totalSpent: 12000,
        todaySpending: 0,
        referenceDate: DateTime(2026, 8, 10),
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );
      final summaryOverrun = calculationService.buildSummary(
        inputOverrun,
        currency: '₹',
      );
      expect(summaryOverrun.budgetUtilization, 1.20);
      expect(summaryOverrun.budgetUtilization.clamp(0.0, 1.0), 1.0);
    });

    test('Test 6 – Today\'s Safe Spending under limit', () {
      final input = BudgetCalculationInput(
        monthlyAmount: 10000,
        totalSpent: 900,
        todaySpending: 900,
        referenceDate: DateTime(2026, 8, 26), // 6 remaining days including 26th
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );

      final summary = calculationService.buildSummary(input, currency: '₹');
      expect(summary.dailySafeSpending, closeTo(1666.67, 0.01));
      expect(summary.todaySpending, 900);
      expect(summary.todayOverspending, 0);
    });

    test('Test 7 – Today\'s Safe Spending Exceeded limit preserved', () {
      final input = BudgetCalculationInput(
        monthlyAmount: 10000,
        totalSpent: 1800,
        todaySpending: 1800,
        referenceDate: DateTime(2026, 8, 26), // 6 remaining days including 26th
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );

      final summary = calculationService.buildSummary(input, currency: '₹');
      expect(summary.dailySafeSpending, closeTo(1666.67, 0.01));
      expect(summary.todaySpending, 1800);
      expect(summary.todayOverspending, closeTo(133.33, 0.01));
    });
  });
}
