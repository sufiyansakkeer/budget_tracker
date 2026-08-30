import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
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
import 'package:monivo/features/expenses/presentation/history/pages/expense_history_screen.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/expense_history_item.dart';

class FakeRepository implements ExpenseRepository {
  final List<ExpenseEntity> expenses;
  FakeRepository(this.expenses);

  @override
  Future<void> createExpense(ExpenseEntity e) async {}
  @override
  Future<void> updateExpense(ExpenseEntity e) async {}
  @override
  Future<void> deleteExpense(String id) async {}
  @override
  Future<ExpenseEntity?> getExpenseById(String id) async => null;
  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
  }) async => expenses;
  @override
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  }) async => expenses.where((e) => budgetIds.contains(e.budgetId)).toList();
  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;
}

class FakeBudgetRepo implements BudgetRepository {
  final BudgetEntity budget;
  FakeBudgetRepo(this.budget);

  @override
  Future<BudgetEntity?> getActiveBudget() async => budget;
  @override
  Future<String?> getActiveBudgetId() async => budget.id;
  @override
  Future<void> setActiveBudgetId(String budgetId) async {}
  @override
  Future<BudgetEntity?> getBudgetById(String id) async => budget;
  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async => [budget];
  @override
  Future<BudgetEntity> createBudget(BudgetEntity b) async => b;
  @override
  Future<BudgetEntity> updateBudget(BudgetEntity b) async => b;
  @override
  Future<void> deleteBudget(String id) async {}
  @override
  Future<BudgetEntity> setBudgetArchived(
    String id, {
    required bool archived,
  }) async => budget;
  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async => budget;
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
  }) async =>
      BudgetError(BudgetFailure(type: BudgetErrorType.notFound, message: ''));
  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}
  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => 0;
}

void main() {
  // All expenses on the SAME date so date grouping puts them in one group.
  // That way sort order within the group is unambiguous.
  final today = DateTime(2026, 8, 29);
  final expenses = [
    ExpenseEntity(
      id: '1',
      budgetId: 'b1',
      amount: 500,
      categoryId: 'food',
      date: today,
      time: today,
      createdAt: today,
      updatedAt: today,
    ),
    ExpenseEntity(
      id: '2',
      budgetId: 'b1',
      amount: 2000,
      categoryId: 'food',
      date: today,
      time: today,
      createdAt: today,
      updatedAt: today,
    ),
    ExpenseEntity(
      id: '3',
      budgetId: 'b1',
      amount: 800,
      categoryId: 'food',
      date: today,
      time: today,
      createdAt: today,
      updatedAt: today,
    ),
    ExpenseEntity(
      id: '4',
      budgetId: 'b1',
      amount: 200,
      categoryId: 'food',
      date: today,
      time: today,
      createdAt: today,
      updatedAt: today,
    ),
    ExpenseEntity(
      id: '5',
      budgetId: 'b1',
      amount: 1500,
      categoryId: 'food',
      date: today,
      time: today,
      createdAt: today,
      updatedAt: today,
    ),
  ];

  Widget buildScreen(ExpenseHistoryBloc bloc) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<ExpenseHistoryBloc>.value(
        value: bloc,
        child: const ExpenseHistoryScreen(),
      ),
    );
  }

  ExpenseHistoryBloc makeBloc() {
    final repo = FakeRepository(expenses);
    return ExpenseHistoryBloc(
      getExpensesUseCase: GetExpensesUseCase(repository: repo),
      getExpensesForBudgetsUseCase: GetExpensesForBudgetsUseCase(
        repository: repo,
      ),
      getCategoriesUseCase: GetCategoriesUseCase(repository: repo),
      searchExpensesUseCase: const SearchExpensesUseCase(),
      filterExpensesUseCase: const FilterExpensesUseCase(),
      sortExpensesUseCase: const SortExpensesUseCase(),
      calculateExpenseSummaryUseCase: const CalculateExpenseSummaryUseCase(),
      pageExpensesUseCase: const PageExpensesUseCase(pageSize: 50),
      budgetRepository: FakeBudgetRepo(
        BudgetEntity(
          id: 'b1',
          name: 'Test',
          monthlyAmount: 30000,
          remainingAmount: 30000,
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ),
    );
  }

  // Helper: extract the ordered list of ₹ amounts from the ExpenseHistoryItem widgets
  List<double> displayedAmounts(WidgetTester tester) {
    final items = tester.widgetList<ExpenseHistoryItem>(
      find.byType(ExpenseHistoryItem),
    );
    return items.map((w) => w.expense.amount).toList();
  }

  testWidgets('Sort by Highest Amount reorders the list', (tester) async {
    final bloc = makeBloc();
    addTearDown(bloc.close);

    bloc.add(const ExpenseHistoryLoad());
    await bloc.stream.firstWhere(
      (s) => s.status == ExpenseHistoryStatus.loaded,
    );

    await tester.pumpWidget(buildScreen(bloc));
    await tester.pumpAndSettle();

    // Default sort (newestFirst) — all same date so order is undefined but all 5 must appear.
    final before = displayedAmounts(tester);
    expect(before.length, 5, reason: 'All 5 expenses must be visible');

    // Dispatch sort change
    bloc.add(const ExpenseHistorySortChanged(ExpenseSortOption.highestAmount));
    await bloc.stream.firstWhere(
      (s) => s.sort == ExpenseSortOption.highestAmount,
    );
    await tester.pumpAndSettle();

    final after = displayedAmounts(tester);
    expect(after.length, 5);
    // Highest amount first
    expect(after.first, 2000.0);
    expect(after.last, 200.0);
  });

  testWidgets('Sort by Lowest Amount reorders the list', (tester) async {
    final bloc = makeBloc();
    addTearDown(bloc.close);

    bloc.add(const ExpenseHistoryLoad());
    await bloc.stream.firstWhere(
      (s) => s.status == ExpenseHistoryStatus.loaded,
    );

    await tester.pumpWidget(buildScreen(bloc));
    await tester.pumpAndSettle();

    bloc.add(const ExpenseHistorySortChanged(ExpenseSortOption.lowestAmount));
    await bloc.stream.firstWhere(
      (s) => s.sort == ExpenseSortOption.lowestAmount,
    );
    await tester.pumpAndSettle();

    final after = displayedAmounts(tester);
    expect(after.first, 200.0, reason: 'Lowest amount should be first');
    expect(after.last, 2000.0, reason: 'Highest amount should be last');
  });

  testWidgets('Sort survives pull-to-refresh', (tester) async {
    final bloc = makeBloc();
    addTearDown(bloc.close);

    bloc.add(const ExpenseHistoryLoad());
    await bloc.stream.firstWhere(
      (s) => s.status == ExpenseHistoryStatus.loaded,
    );

    await tester.pumpWidget(buildScreen(bloc));
    await tester.pumpAndSettle();

    // Set to highest amount
    bloc.add(const ExpenseHistorySortChanged(ExpenseSortOption.highestAmount));
    await bloc.stream.firstWhere(
      (s) => s.sort == ExpenseSortOption.highestAmount,
    );
    await tester.pumpAndSettle();

    // Simulate refresh
    bloc.add(const ExpenseHistoryRefresh());
    await bloc.stream.firstWhere(
      (s) =>
          s.status == ExpenseHistoryStatus.loaded && s.allExpenses.length == 5,
    );
    await tester.pumpAndSettle();

    // Sort should survive
    expect(bloc.state.sort, ExpenseSortOption.highestAmount);
    final after = displayedAmounts(tester);
    expect(after.first, 2000.0);
  });
}
