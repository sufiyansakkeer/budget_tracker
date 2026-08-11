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
    await localDataSource.createExpense(expense);
    await budgetRepository.updateBudgetRemainingAmount(expense.budgetId);
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    await localDataSource.updateExpense(expense);
    await budgetRepository.updateBudgetRemainingAmount(expense.budgetId);
  }

  @override
  Future<void> deleteExpense(String id) async {
    final expense = await localDataSource.getExpenseById(id);
    if (expense != null) {
      await localDataSource.deleteExpense(id);
      await budgetRepository.updateBudgetRemainingAmount(expense.budgetId);
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
  }) {
    return localDataSource.getExpenses(
      budgetId: budgetId,
      month: month,
      year: year,
    );
  }

  @override
  Future<List<ExpenseCategory>> getCategories() {
    return localDataSource.getCategories();
  }
}
