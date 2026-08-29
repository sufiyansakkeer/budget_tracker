import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../models/expense_category_model.dart';
import '../models/expense_model.dart';
import 'expense_local_datasource.dart';

class ExpenseLocalDataSourceImpl implements ExpenseLocalDataSource {
  final AppDatabase database;

  ExpenseLocalDataSourceImpl({required this.database});

  @override
  Future<void> createExpense(ExpenseEntity expense) async {
    await database
        .into(database.expenses)
        .insert(ExpenseModel.toCompanion(expense));
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    await (database.update(
      database.expenses,
    )..where((e) => e.id.equals(expense.id))).write(
      ExpensesCompanion(
        budgetId: Value(expense.budgetId),
        amount: Value(expense.amount),
        categoryId: Value(expense.categoryId),
        note: Value(expense.note),
        date: Value(expense.date),
        time: Value(expense.time),
        receiptImagePath: Value(expense.receiptImagePath),
        tags: Value(ExpenseModel.encodeTags(expense.tags)),
        updatedAt: Value(expense.updatedAt),
      ),
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    await (database.delete(
      database.expenses,
    )..where((e) => e.id.equals(id))).go();
  }

  @override
  Future<ExpenseEntity?> getExpenseById(String id) async {
    final query = database.select(database.expenses)
      ..where((e) => e.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return ExpenseModel.toEntity(row);
  }

  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
  }) async {
    final query = database.select(database.expenses);

    if (budgetId != null) {
      query.where((e) => e.budgetId.equals(budgetId));
    }

    if (month != null && year != null) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59, 999);
      query.where(
        (e) =>
            e.date.isBiggerOrEqualValue(start) &
            e.date.isSmallerOrEqualValue(end),
      );
    }

    query.orderBy([(e) => OrderingTerm.desc(e.date)]);
    final rows = await query.get();
    return rows.map(ExpenseModel.toEntity).toList();
  }

  @override
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  }) async {
    if (budgetIds.isEmpty) return const [];

    final query = database.select(database.expenses)
      ..where((e) => e.budgetId.isIn(budgetIds))
      ..orderBy([(e) => OrderingTerm.desc(e.date)]);
    final rows = await query.get();
    return rows.map(ExpenseModel.toEntity).toList();
  }

  @override
  Future<List<ExpenseCategory>> getCategories() async {
    final rows = await (database.select(database.categories)).get();
    if (rows.isEmpty) {
      // Lazily seed default categories on first access.
      await seedDefaultCategories(defaultCategories);
      final seeded = await (database.select(database.categories)).get();
      return seeded.map(ExpenseCategoryModel.toEntity).toList();
    }
    return rows.map(ExpenseCategoryModel.toEntity).toList();
  }

  @override
  Future<void> seedDefaultCategories(List<ExpenseCategory> categories) async {
    for (final category in categories) {
      await database
          .into(database.categories)
          .insert(
            ExpenseCategoryModel.toCompanion(category),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}
