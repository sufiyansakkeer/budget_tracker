import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/repository/expense_repository.dart';
import 'package:monivo/features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/page_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/search_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/sort_expenses_usecase.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_event.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_state.dart';

ExpenseEntity expense({
  required String id,
  double amount = 100,
  String categoryId = 'food',
  String? note,
  DateTime? date,
  List<String> tags = const [],
}) {
  final now = date ?? DateTime(2026, 8, 5);
  return ExpenseEntity(
    id: id,
    budgetId: 'budget-1',
    amount: amount,
    categoryId: categoryId,
    note: note,
    date: now,
    time: now,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );
}

class FakeHistoryRepository implements ExpenseRepository {
  final List<ExpenseEntity> expenses = [
    expense(id: '1', amount: 100, note: 'Lunch'),
    expense(id: '2', amount: 300, note: 'Fuel'),
    expense(id: '3', amount: 200, note: 'Groceries', categoryId: 'grocery'),
  ];

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
  }) async => expenses;
  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;
}

class FakeBudgetRepository implements BudgetRepository {
  final BudgetEntity? budget;
  FakeBudgetRepository({this.budget});

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
  }) async => budget == null ? [] : [budget!];
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
  }) async => budget ?? (throw StateError('No budget'));
  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async => budget ?? (throw StateError('No budget'));
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
  }) async {
    if (budget == null || budgetId != budget!.id) {
      return BudgetError(
        BudgetFailure(
          type: BudgetErrorType.notFound,
          message: 'Budget not found',
        ),
      );
    }
    return BudgetSuccess(
      BudgetCalculationContext(
        budget: budget!,
        statistics: MonthlyStatisticsEntity.empty,
        referenceDate: referenceDate ?? DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}
}

ExpenseHistoryBloc buildBloc(FakeHistoryRepository repository) {
  return ExpenseHistoryBloc(
    getExpensesUseCase: GetExpensesUseCase(repository: repository),
    getCategoriesUseCase: GetCategoriesUseCase(repository: repository),
    searchExpensesUseCase: const SearchExpensesUseCase(),
    filterExpensesUseCase: const FilterExpensesUseCase(),
    sortExpensesUseCase: const SortExpensesUseCase(),
    calculateExpenseSummaryUseCase: const CalculateExpenseSummaryUseCase(),
    pageExpensesUseCase: const PageExpensesUseCase(pageSize: 2),
    budgetRepository: FakeBudgetRepository(
      budget: BudgetEntity(
        id: 'budget-1',
        name: 'Personal',
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

void main() {
  late FakeHistoryRepository repository;
  late ExpenseHistoryBloc bloc;

  setUp(() {
    repository = FakeHistoryRepository();
    bloc = buildBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
  });

  test('initial state is initial', () {
    expect(bloc.state.status, ExpenseHistoryStatus.initial);
    expect(bloc.state.allExpenses, isEmpty);
  });

  test('loads expenses and categories', () async {
    bloc.add(const ExpenseHistoryLoad());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, ExpenseHistoryStatus.loaded);
    expect(bloc.state.allExpenses.length, 3);
    expect(bloc.state.categories.length, defaultCategories.length);
    expect(bloc.state.summary.totalExpenses, 3);
  });

  test('applies search filter', () async {
    bloc.add(const ExpenseHistoryLoad());
    await Future<void>.delayed(Duration.zero);

    bloc.add(const ExpenseHistorySearchChanged('lunch'));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(bloc.state.visibleExpenses.length, 1);
    expect(bloc.state.visibleExpenses.first.note, 'Lunch');
  });

  test('applies category filter', () async {
    bloc.add(const ExpenseHistoryLoad());
    await Future<void>.delayed(Duration.zero);

    bloc.add(
      const ExpenseHistoryFilterChanged(
        ExpenseHistoryFilter(categoryId: 'food'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.visibleExpenses.length, 2);
  });

  test('applies sort by amount', () async {
    bloc.add(const ExpenseHistoryLoad());
    await Future<void>.delayed(Duration.zero);

    bloc.add(const ExpenseHistorySortChanged(ExpenseSortOption.highestAmount));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.visibleExpenses.first.amount, 300);
  });

  test('loads more pages', () async {
    bloc.add(const ExpenseHistoryLoad());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.loadedExpenses.length, 2); // page size 2
    expect(bloc.state.hasMore, isTrue);

    bloc.add(const ExpenseHistoryLoadMore());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.loadedExpenses.length, 3);
    expect(bloc.state.hasMore, isFalse);
  });

  test('clears filters restores all', () async {
    bloc.add(const ExpenseHistoryLoad());
    await Future<void>.delayed(Duration.zero);

    bloc.add(
      const ExpenseHistoryFilterChanged(
        ExpenseHistoryFilter(categoryId: 'food'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.visibleExpenses.length, 2);

    bloc.add(const ExpenseHistoryClearFilters());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.visibleExpenses.length, 3);
  });
}
