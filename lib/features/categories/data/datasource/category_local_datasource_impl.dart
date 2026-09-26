import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../expenses/data/models/expense_category_model.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import 'category_local_datasource.dart';

class CategoryLocalDataSourceImpl implements CategoryLocalDataSource {
  final AppDatabase database;

  CategoryLocalDataSourceImpl({required this.database});

  @override
  Future<List<ExpenseCategory>> getCategories() async {
    await database.seedDefaultCategories();
    final rows = await database.select(database.categories).get();
    return rows.map(ExpenseCategoryModel.toEntity).toList();
  }

  @override
  Future<ExpenseCategory?> getCategoryById(String id) async {
    final row = await (database.select(
      database.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : ExpenseCategoryModel.toEntity(row);
  }

  @override
  Future<void> createCategory(ExpenseCategory category) async {
    await database
        .into(database.categories)
        .insert(ExpenseCategoryModel.toCompanion(category));
  }

  @override
  Future<void> updateCategory(ExpenseCategory category) async {
    await (database.update(
      database.categories,
    )..where((c) => c.id.equals(category.id))).write(
      CategoriesCompanion(
        name: Value(category.name),
        icon: Value(category.icon),
        colorHex: Value(category.colorHex),
        isArchived: Value(category.isArchived),
      ),
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    await (database.delete(
      database.categories,
    )..where((c) => c.id.equals(id))).go();
  }

  @override
  Future<int> countExpenses(String categoryId) async {
    final count = database.expenses.id.count();
    final row =
        await (database.selectOnly(database.expenses)
              ..addColumns([count])
              ..where(database.expenses.categoryId.equals(categoryId)))
            .getSingle();
    return row.read(count) ?? 0;
  }
}
