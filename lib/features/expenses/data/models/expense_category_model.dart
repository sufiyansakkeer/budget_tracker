import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/expense_category.dart';

/// Maps between the Drift [Category] row and [ExpenseCategory].
class ExpenseCategoryModel {
  ExpenseCategoryModel._();

  static ExpenseCategory toEntity(Category row) {
    return ExpenseCategory(
      id: row.id,
      name: row.name,
      icon: row.icon,
      colorHex: row.colorHex,
      isSystem: row.isSystem,
    );
  }

  static CategoriesCompanion toCompanion(ExpenseCategory category) {
    return CategoriesCompanion.insert(
      id: category.id,
      name: category.name,
      icon: category.icon,
      colorHex: category.colorHex,
      isSystem: Value(category.isSystem),
    );
  }
}
