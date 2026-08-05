import 'package:drift/drift.dart';

import '../../database/app_database.dart';
import '../../domain/entities/budget_entity.dart';

class BudgetModel {
  static BudgetEntity toEntity(Budget row) {
    return BudgetEntity(
      id: row.id,
      monthlyAmount: row.monthlyAmount,
      remainingAmount: row.remainingAmount,
      currency: row.currency,
      month: row.month,
      year: row.year,
      createdAt: row.createdAt,
    );
  }

  static BudgetsCompanion toCompanion(BudgetEntity entity) {
    return BudgetsCompanion.insert(
      id: entity.id,
      monthlyAmount: entity.monthlyAmount,
      remainingAmount: entity.remainingAmount,
      currency: entity.currency,
      month: entity.month,
      year: entity.year,
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.createdAt),
    );
  }
}
