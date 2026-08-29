import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/repository/expense_repository.dart';
import 'package:monivo/features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_for_budgets_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/page_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/search_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/sort_expenses_usecase.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_event.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_state.dart';

// ── Helpers ────────────────────────────────────────────────────────────

ExpenseEntity expense({
  required String id,
  required String budgetId,
  double amount = 100,
  String categoryId = 'food',
  String? note,
  DateTime? date,
}) {
  final now = date ?? DateTime(2026, 8, 20);
  return ExpenseEntity(
    id: id,
    budgetId: budgetId,
    amount: amount,
    categoryId: categoryId,
    note: note,
    date: now,
    time: now,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetEntity budget({
  required String id,
  required String name,
  double monthlyAmount = 30000,
  bool isArchived = false,
}) {
  return BudgetEntity(
    id: id,
    name: name,
    monthlyAmount: monthlyAmount,
    remainingAmount: monthlyAmount,
    currency: 'INR',
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 31),
    isArchived: isArchived,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

class FakeRepository implements ExpenseRepository {
  final List<ExpenseEntity> allExpenses;

  FakeRepository(this.allExpenses);

  @override
  Future<void> createExpense(ExpenseEntity expense) async {}
  @override
  Future<void> updateExpense(ExpenseEntity expense) async {}
  @override
  Future<void> deleteExpense(String id) async {}
  @override
  Future<ExpenseEntity?> getExpenseById(String id) async => null;
  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
  }) async {
    if (budgetId != null) {
      return allExpenses.where((e) => e.budgetId == budgetId).toList();
    }
    return allExpenses;
  }

  @override
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  }) async => allExpenses.where((e) => budgetIds.contains(e.budgetId)).toList();

  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;
}

class FakeBudgetRepo implements BudgetRepository {
  final List<BudgetEntity> budgets;
  final String? activeBudgetId;

  FakeBudgetRepo({required this.budgets, this.activeBudgetId});

  @override
  Future<BudgetEntity?> getActiveBudget() async =>
      budgets.where((b) => b.id == activeBudgetId).firstOrNull;
  @override
  Future<String?> getActiveBudgetId() async => activeBudgetId;
  @override
  Future<void> setActiveBudgetId(String budgetId) async {}
  @override
  Future<BudgetEntity?> getBudgetById(String id) async =>
      budgets.where((b) => b.id == id).firstOrNull;
  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async => budgets;
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
  }) async => budgets.first;
  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async => budgets.first;
  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => MonthlyStatisticsEntity.empty;
  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 0;
  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 1;
  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async => BudgetError(
    BudgetFailure(type: BudgetErrorType.notFound, message: 'Not used'),
  );
  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}
  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => 0.0;
}

// ── Budgets ────────────────────────────────────────────────────────────

final _budgetFood = budget(id: 'food', name: 'Food');
final _budgetTravel = budget(id: 'travel', name: 'Travel');
final _budgetShopping = budget(id: 'shopping', name: 'Shopping');

// ── Expenses ───────────────────────────────────────────────────────────

final _expenses = [
  expense(id: 'e1', budgetId: 'food', amount: 500, note: 'Restaurant'),
  expense(
    id: 'e2',
    budgetId: 'food',
    amount: 200,
    note: 'Groceries',
    categoryId: 'grocery',
  ),
  expense(
    id: 'e3',
    budgetId: 'travel',
    amount: 300,
    note: 'Fuel',
    categoryId: 'fuel',
  ),
  expense(
    id: 'e4',
    budgetId: 'travel',
    amount: 150,
    note: 'Train',
    categoryId: 'travel',
  ),
  expense(id: 'e5', budgetId: 'shopping', amount: 800, note: 'Shoes'),
  expense(
    id: 'e6',
    budgetId: 'shopping',
    amount: 400,
    note: 'Clothes',
    date: DateTime(2026, 8, 15),
  ),
];

ExpenseHistoryBloc _buildBloc(
  FakeRepository repository,
  FakeBudgetRepo budgetRepo,
) {
  return ExpenseHistoryBloc(
    getExpensesUseCase: GetExpensesUseCase(repository: repository),
    getExpensesForBudgetsUseCase: GetExpensesForBudgetsUseCase(
      repository: repository,
    ),
    getCategoriesUseCase: GetCategoriesUseCase(repository: repository),
    searchExpensesUseCase: const SearchExpensesUseCase(),
    filterExpensesUseCase: const FilterExpensesUseCase(),
    sortExpensesUseCase: const SortExpensesUseCase(),
    calculateExpenseSummaryUseCase: const CalculateExpenseSummaryUseCase(),
    pageExpensesUseCase: const PageExpensesUseCase(pageSize: 50),
    budgetRepository: budgetRepo,
  );
}

// ── Tests ──────────────────────────────────────────────────────────────

void main() {
  group('Combined mode — single budget selected', () {
    test(
      'Test 1 — only Food expenses returned when Food is selected',
      () async {
        final repo = FakeRepository(_expenses);
        final budgetRepo = FakeBudgetRepo(
          budgets: [_budgetFood, _budgetTravel, _budgetShopping],
          activeBudgetId: 'food',
        );
        final bloc = _buildBloc(repo, budgetRepo);
        addTearDown(bloc.close);

        // Enter combined mode
        bloc.add(const ExpenseHistoryToggleViewMode());
        await Future<void>.delayed(Duration.zero);

        // Select Food
        bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
        await Future<void>.delayed(Duration.zero);

        // Apply
        bloc.add(const ExpenseHistoryApplyCombinedView());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bloc.state.isCombinedMode, isTrue);
        expect(bloc.state.visibleExpenses.length, 2);
        expect(
          bloc.state.visibleExpenses.every((e) => e.budgetId == 'food'),
          isTrue,
        );
      },
    );
  });

  group('Combined mode — multiple budgets', () {
    test('Test 2 — Food + Travel returns expenses from both', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.visibleExpenses.length, 4);
      final budgetIds = bloc.state.visibleExpenses
          .map((e) => e.budgetId)
          .toSet();
      expect(budgetIds, containsAll(['food', 'travel']));
      expect(budgetIds.contains('shopping'), isFalse);
    });

    test('Test 3 — Three budgets returns all expenses', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('shopping'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.visibleExpenses.length, 6);
    });
  });

  group('Combined mode — exclusion', () {
    test(
      'Test 4 — Shopping expense excluded when only Food + Travel selected',
      () async {
        final repo = FakeRepository(_expenses);
        final budgetRepo = FakeBudgetRepo(
          budgets: [_budgetFood, _budgetTravel, _budgetShopping],
          activeBudgetId: 'food',
        );
        final bloc = _buildBloc(repo, budgetRepo);
        addTearDown(bloc.close);

        bloc.add(const ExpenseHistoryToggleViewMode());
        await Future<void>.delayed(Duration.zero);

        bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
        bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const ExpenseHistoryApplyCombinedView());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          bloc.state.visibleExpenses.any((e) => e.budgetId == 'shopping'),
          isFalse,
        );
      },
    );
  });

  group('Combined mode — search', () {
    test('Test 5 — Search across selected budgets', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Search for "Restaurant" — should only find the food expense
      bloc.add(const ExpenseHistorySearchChanged('Restaurant'));
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(bloc.state.visibleExpenses.length, 1);
      expect(bloc.state.visibleExpenses.first.budgetId, 'food');
      expect(bloc.state.visibleExpenses.first.note, 'Restaurant');
    });
  });

  group('Combined mode — category filter', () {
    test('Test 6 — Category filter works across multiple budgets', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Filter by 'food' category
      bloc.add(
        const ExpenseHistoryFilterChanged(
          ExpenseHistoryFilter(categoryId: 'food'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.visibleExpenses.length, 1);
      expect(bloc.state.visibleExpenses.first.categoryId, 'food');
      expect(bloc.state.visibleExpenses.first.budgetId, 'food');
    });
  });

  group('Combined mode — date filter', () {
    test('Test 7 — Date filter works across selected budgets', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryToggleBudgetSelection('shopping'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Filter to Aug 15 only — e6 has date 2026-08-15
      bloc.add(
        ExpenseHistoryFilterChanged(
          ExpenseHistoryFilter(
            dateFrom: DateTime(2026, 8, 15),
            dateTo: DateTime(2026, 8, 15),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.visibleExpenses.length, 1);
      expect(bloc.state.visibleExpenses.first.id, 'e6');
    });
  });

  group('Combined mode — empty selection', () {
    test('Test 8 — Applying with zero budgets shows error', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      // Don't select any budgets
      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, ExpenseHistoryStatus.error);
      expect(bloc.state.selectedBudgetIds, isEmpty);
    });
  });

  group('Combined mode — delete expense', () {
    test('Test 9 — Deleting removes expense from combined view', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final countBefore = bloc.state.allExpenses.length;
      expect(countBefore, 4);

      // Simulate deleting expense e3 (travel expense)
      final updatedExpenses = _expenses.where((e) => e.id != 'e3').toList();
      final updatedRepo = FakeRepository(updatedExpenses);
      final updatedBloc = _buildBloc(updatedRepo, budgetRepo);
      addTearDown(updatedBloc.close);

      updatedBloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      updatedBloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      updatedBloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      await Future<void>.delayed(Duration.zero);

      updatedBloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(updatedBloc.state.visibleExpenses.length, 3);
      expect(
        updatedBloc.state.visibleExpenses.any((e) => e.id == 'e3'),
        isFalse,
      );
    });
  });

  group('Combined mode — edit expense budget', () {
    test(
      'Test 10 — Changing budget removes expense from combined view',
      () async {
        // e1 is food (500). If we change it to shopping, it should disappear
        // from a food+travel combined view.
        final updatedExpenses = _expenses.map((e) {
          if (e.id == 'e1') return e.copyWith(budgetId: 'shopping');
          return e;
        }).toList();

        final repo = FakeRepository(updatedExpenses);
        final budgetRepo = FakeBudgetRepo(
          budgets: [_budgetFood, _budgetTravel, _budgetShopping],
          activeBudgetId: 'food',
        );
        final bloc = _buildBloc(repo, budgetRepo);
        addTearDown(bloc.close);

        bloc.add(const ExpenseHistoryToggleViewMode());
        await Future<void>.delayed(Duration.zero);

        bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
        bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const ExpenseHistoryApplyCombinedView());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // e1 was moved to shopping — should not appear
        expect(bloc.state.visibleExpenses.any((e) => e.id == 'e1'), isFalse);
        // Only 3 remaining (e2, e3, e4) since e1 moved to shopping
        expect(bloc.state.visibleExpenses.length, 3);
      },
    );
  });

  group('Combined mode — budget info', () {
    test('Test 11 — Budget map resolves correct budget name', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.allBudgets.length, 3);
      expect(bloc.state.budgetMap['food']?.name, 'Food');
      expect(bloc.state.budgetMap['travel']?.name, 'Travel');
      expect(bloc.state.budgetMap['shopping']?.name, 'Shopping');
    });
  });

  group('Combined mode — total', () {
    test('Test 12 — Combined total only includes selected budgets', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Food: 500 + 200 = 700, Travel: 300 + 150 = 450, Total = 1150
      expect(bloc.state.combinedTotalAmount, 1150);
    });
  });

  group('Combined mode — toggle selection', () {
    test('SelectAll and ClearAll work correctly', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      // Select all
      bloc.add(const ExpenseHistorySelectAllBudgets());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.selectedBudgetIds.length, 3);

      // Clear all
      bloc.add(const ExpenseHistoryClearBudgetSelection());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.selectedBudgetIds, isEmpty);
    });

    test('Toggle individual budget', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.selectedBudgetIds, ['food']);

      // Toggle off
      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.selectedBudgetIds, isEmpty);
    });
  });

  group('Combined mode — exit', () {
    test('Exiting combined mode returns to single budget', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isCombinedMode, isTrue);

      bloc.add(const ExpenseHistoryExitCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.isCombinedMode, isFalse);
      expect(bloc.state.selectedBudgetIds, isEmpty);
    });
  });

  group('Combined mode — selectedBudgetsLabel', () {
    test('Shows compact label for many budgets', () {
      final state = ExpenseHistoryState(
        selectedBudgetIds: ['a', 'b', 'c', 'd'],
        budgetMap: {
          'a': budget(id: 'a', name: 'Food'),
          'b': budget(id: 'b', name: 'Travel'),
          'c': budget(id: 'c', name: 'Shopping'),
          'd': budget(id: 'd', name: 'Entertainment'),
        },
      );
      expect(state.selectedBudgetsLabel, 'Food • Travel • Shopping +1');
    });

    test('Shows all names when 3 or fewer', () {
      final state = ExpenseHistoryState(
        selectedBudgetIds: ['a', 'b'],
        budgetMap: {
          'a': budget(id: 'a', name: 'Food'),
          'b': budget(id: 'b', name: 'Travel'),
        },
      );
      expect(state.selectedBudgetsLabel, 'Food • Travel');
    });
  });

  group('Combined mode — archived budgets excluded', () {
    test('Only non-archived budgets appear in allBudgets', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [
          _budgetFood,
          _budgetTravel,
          budget(id: 'archived', name: 'Old', isArchived: true),
        ],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.allBudgets.length, 2);
      expect(bloc.state.allBudgets.every((b) => !b.isArchived), isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Combined mode — refresh persistence tests
  // Verifies that pull-to-refresh preserves selected budgets, sort,
  // filters, and view mode.
  // ──────────────────────────────────────────────────────────────

  group('Combined mode — refresh persistence', () {
    test('Test R1 — selected budgets survive refresh', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      // Enter combined mode and select Food + Travel
      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selectedBudgetIds, containsAll(['food', 'travel']));
      expect(bloc.state.visibleExpenses.length, 4);

      // Refresh
      bloc.add(const ExpenseHistoryRefresh());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Selections must survive
      expect(bloc.state.selectedBudgetIds, containsAll(['food', 'travel']));
      expect(bloc.state.isCombinedMode, isTrue);
      expect(bloc.state.visibleExpenses.length, 4);
    });

    test('Test R2 — three selected budgets survive refresh', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('shopping'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selectedBudgetIds.length, 3);

      // Refresh
      bloc.add(const ExpenseHistoryRefresh());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selectedBudgetIds.length, 3);
      expect(bloc.state.visibleExpenses.length, 6);
    });

    test(
      'Test R3 — expenses after refresh belong only to selected budgets',
      () async {
        final repo = FakeRepository(_expenses);
        final budgetRepo = FakeBudgetRepo(
          budgets: [_budgetFood, _budgetTravel, _budgetShopping],
          activeBudgetId: 'food',
        );
        final bloc = _buildBloc(repo, budgetRepo);
        addTearDown(bloc.close);

        // Select only Food + Travel (Shopping must NOT appear)
        bloc.add(const ExpenseHistoryToggleViewMode());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
        bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ExpenseHistoryApplyCombinedView());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Refresh
        bloc.add(const ExpenseHistoryRefresh());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Shopping expenses must NOT appear
        expect(
          bloc.state.visibleExpenses.any((e) => e.budgetId == 'shopping'),
          isFalse,
          reason: 'Shopping expenses must not appear when not selected',
        );
      },
    );

    test('Test R4 — search filter survives refresh in combined mode', () async {
      final repo = FakeRepository(_expenses);
      final budgetRepo = FakeBudgetRepo(
        budgets: [_budgetFood, _budgetTravel, _budgetShopping],
        activeBudgetId: 'food',
      );
      final bloc = _buildBloc(repo, budgetRepo);
      addTearDown(bloc.close);

      bloc.add(const ExpenseHistoryToggleViewMode());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
      bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ExpenseHistoryApplyCombinedView());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Search for "Restaurant"
      bloc.add(const ExpenseHistorySearchChanged('Restaurant'));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(bloc.state.visibleExpenses.length, 1);

      // Refresh
      bloc.add(const ExpenseHistoryRefresh());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Search must still be active
      expect(bloc.state.query, 'Restaurant');
      expect(bloc.state.visibleExpenses.length, 1);
      expect(bloc.state.selectedBudgetIds, containsAll(['food', 'travel']));
    });

    test(
      'Test R5 — sort selection survives refresh in combined mode',
      () async {
        final repo = FakeRepository(_expenses);
        final budgetRepo = FakeBudgetRepo(
          budgets: [_budgetFood, _budgetTravel, _budgetShopping],
          activeBudgetId: 'food',
        );
        final bloc = _buildBloc(repo, budgetRepo);
        addTearDown(bloc.close);

        bloc.add(const ExpenseHistoryToggleViewMode());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ExpenseHistoryToggleBudgetSelection('food'));
        bloc.add(const ExpenseHistoryToggleBudgetSelection('travel'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ExpenseHistoryApplyCombinedView());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Set sort to highest amount
        bloc.add(
          const ExpenseHistorySortChanged(ExpenseSortOption.highestAmount),
        );
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.sort, ExpenseSortOption.highestAmount);

        // Refresh
        bloc.add(const ExpenseHistoryRefresh());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Sort must survive refresh
        expect(bloc.state.sort, ExpenseSortOption.highestAmount);
        expect(bloc.state.isCombinedMode, isTrue);
        expect(bloc.state.selectedBudgetIds, containsAll(['food', 'travel']));
      },
    );
  });
}
