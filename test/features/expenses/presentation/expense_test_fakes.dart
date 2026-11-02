import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/repository/expense_repository.dart';
import 'package:monivo/features/expenses/domain/usecases/create_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/delete_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expense_by_id_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/update_expense_usecase.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_purchase_usecase.dart';
import '../../../helpers/pay_later_fakes.dart';

/// Expenses kept in a map, with the date-range and budget filters the real
/// datasource applies.
class MemoryExpenseRepository implements ExpenseRepository {
  final Map<String, ExpenseEntity> store = {};
  List<ExpenseCategory> categories = defaultCategories;

  /// Set to make every write fail with this message.
  String? failWrites;

  /// Set to make reading one expense fail with this message.
  String? failReadById;

  /// Makes [getCategories] throw with this message.
  String? failCategories;

  @override
  Future<void> createExpense(ExpenseEntity expense) async {
    if (failWrites != null) throw Exception(failWrites);
    store[expense.id] = expense;
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    if (failWrites != null) throw Exception(failWrites);
    store[expense.id] = expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    if (failWrites != null) throw Exception(failWrites);
    store.remove(id);
  }

  @override
  Future<ExpenseEntity?> getExpenseById(String id) async {
    if (failReadById != null) throw Exception(failReadById);
    return store[id];
  }

  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    DateTime? from,
    DateTime? to,
  }) async {
    final start = from == null
        ? null
        : DateTime(from.year, from.month, from.day);
    final end = to == null
        ? null
        : DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return [
      for (final e in store.values)
        if ((budgetId == null || e.budgetId == budgetId) &&
            (start == null || !e.date.isBefore(start)) &&
            (end == null || !e.date.isAfter(end)))
          e,
    ];
  }

  @override
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  }) async => [
    for (final e in store.values)
      if (budgetIds.contains(e.budgetId)) e,
  ];

  @override
  Future<List<ExpenseEntity>> getExpensesForBill(String billId) async => [
    for (final e in store.values)
      if (e.billId == billId) e,
  ];

  @override
  Future<List<ExpenseCategory>> getCategories() async {
    if (failCategories != null) throw Exception(failCategories);
    return categories;
  }
}

/// Budgets by id plus an active id; anything else is not needed here.
class StubBudgetRepository implements BudgetRepository {
  final Map<String, BudgetEntity> budgets = {};
  String? activeId;

  /// Makes reading the active budget throw, as when the database is locked.
  bool failActiveReads = false;

  /// Makes [getAllBudgets] throw.
  bool failListing = false;

  StubBudgetRepository([List<BudgetEntity> initial = const []]) {
    for (final b in initial) {
      budgets[b.id] = b;
    }
    activeId = initial.isEmpty ? null : initial.first.id;
  }

  @override
  Future<String?> getActiveBudgetId() async {
    if (failActiveReads) throw Exception('database is locked');
    return activeId;
  }

  @override
  Future<BudgetEntity?> getBudgetById(String id) async {
    if (failActiveReads) throw Exception('database is locked');
    return budgets[id];
  }

  @override
  Future<BudgetEntity?> getActiveBudget() async {
    if (failActiveReads) throw Exception('database is locked');
    return activeId == null ? null : budgets[activeId];
  }

  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async {
    if (failListing) throw Exception('database is locked');
    return budgets.values.toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BudgetEntity testBudget({
  String id = 'personal',
  String name = 'Personal',
  String currency = 'INR',
  required DateTime start,
  required DateTime end,
  double amount = 30000,
  bool archived = false,
}) => BudgetEntity(
  id: id,
  name: name,
  monthlyAmount: amount,
  remainingAmount: amount,
  currency: currency,
  startDate: start,
  endDate: end,
  createdAt: start,
  updatedAt: start,
  isArchived: archived,
);

/// A real [ExpenseBloc] over the in-memory repositories. [tabPurchases]
/// defaults to a fake on which no expense is on a tab.
ExpenseBloc memoryExpenseBloc(
  MemoryExpenseRepository expenses,
  StubBudgetRepository budgets, {
  TabPurchaseUseCase? tabPurchases,
}) => ExpenseBloc(
  createExpenseUseCase: CreateExpenseUseCase(repository: expenses),
  updateExpenseUseCase: UpdateExpenseUseCase(repository: expenses),
  deleteExpenseUseCase: DeleteExpenseUseCase(repository: expenses),
  getExpenseByIdUseCase: GetExpenseByIdUseCase(repository: expenses),
  getExpensesUseCase: GetExpensesUseCase(repository: expenses),
  getCategoriesUseCase: GetCategoriesUseCase(repository: expenses),
  budgetRepository: budgets,
  tabPurchases: tabPurchases ?? FakeTabPurchaseUseCase(),
);
