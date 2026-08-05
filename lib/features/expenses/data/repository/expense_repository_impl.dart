import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repository/expense_repository.dart';
import '../datasource/expense_local_datasource.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseLocalDataSource localDataSource;

  ExpenseRepositoryImpl({required this.localDataSource});

  @override
  Future<void> createExpense(ExpenseEntity expense) {
    return localDataSource.createExpense(expense);
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) {
    return localDataSource.updateExpense(expense);
  }

  @override
  Future<void> deleteExpense(String id) {
    return localDataSource.deleteExpense(id);
  }

  @override
  Future<ExpenseEntity?> getExpenseById(String id) {
    return localDataSource.getExpenseById(id);
  }

  @override
  Future<List<ExpenseEntity>> getExpenses({int? month, int? year}) {
    return localDataSource.getExpenses(month: month, year: year);
  }

  @override
  Future<List<ExpenseCategory>> getCategories() {
    return localDataSource.getCategories();
  }
}
