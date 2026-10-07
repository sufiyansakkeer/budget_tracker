import '../../../budget/domain/repository/budget_repository.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repository/expense_repository.dart';
import '../datasource/expense_local_datasource.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseLocalDataSource localDataSource;
  final BudgetRepository budgetRepository;

  ExpenseRepositoryImpl({
    required this.localDataSource,
    required this.budgetRepository,
  });

  @override
  Future<void> createExpense(ExpenseEntity expense) async {
    await localDataSource.transaction(() async {
      await localDataSource.createExpense(expense);
      await budgetRepository.updateBudgetRemainingAmount(expense.budgetId);
    });
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    // Read the stored row first: when an expense is moved to another budget
    // both budgets' remaining amounts have to be recomputed, otherwise the
    // budget it left stays short by the amount forever.
    final previous = await localDataSource.getExpenseById(expense.id);
    final previousBudgetId = previous?.budgetId;
    // A bill payment is committed spending only in the budget the bill was
    // set aside in; moved elsewhere it becomes plain spending.
    final moved =
        previousBudgetId != null && previousBudgetId != expense.budgetId;

    await localDataSource.transaction(() async {
      await localDataSource.updateExpense(expense, clearBillId: moved);
      await budgetRepository.updateBudgetRemainingAmount(expense.budgetId);
      if (moved) {
        await budgetRepository.updateBudgetRemainingAmount(previousBudgetId);
      }
    });
  }

  @override
  Future<void> deleteExpense(String id) async {
    final expense = await localDataSource.getExpenseById(id);
    if (expense != null) {
      await localDataSource.transaction(() async {
        await localDataSource.deleteExpense(id);
        await budgetRepository.updateBudgetRemainingAmount(expense.budgetId);
      });
    }
  }

  @override
  Future<ExpenseEntity?> getExpenseById(String id) {
    return localDataSource.getExpenseById(id);
  }

  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
    DateTime? from,
    DateTime? to,
  }) {
    return localDataSource.getExpenses(
      budgetId: budgetId,
      month: month,
      year: year,
      from: from,
      to: to,
    );
  }

  @override
  Future<List<ExpenseEntity>> getExpensesForBill(String billId) {
    return localDataSource.getExpensesForBill(billId);
  }

  @override
  Future<List<ExpenseCategory>> getCategories() {
    return localDataSource.getCategories();
  }

  @override
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  }) {
    return localDataSource.getExpensesForBudgets(budgetIds: budgetIds);
  }
}
