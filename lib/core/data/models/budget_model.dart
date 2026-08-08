import 'package:drift/drift.dart';

import '../../database/app_database.dart';
import '../../domain/entities/budget_entity.dart';

class BudgetModel {
  static BudgetEntity toEntity(Budget row) {
    return BudgetEntity(
      id: row.id,
      name: row.name,
      monthlyAmount: row.monthlyAmount,
      remainingAmount: row.remainingAmount,
      currency: row.currency,
      startDate: row.startDate,
      endDate: row.endDate,
      isArchived: row.isArchived,
      color: row.color,
      icon: row.icon,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static BudgetsCompanion toCompanion(BudgetEntity entity) {
    return BudgetsCompanion.insert(
      id: entity.id,
      name: entity.name,
      monthlyAmount: entity.monthlyAmount,
      remainingAmount: entity.remainingAmount,
      currency: entity.currency,
      startDate: entity.startDate,
      endDate: entity.endDate,
      isArchived: Value(entity.isArchived),
      color: Value(entity.color),
      icon: Value(entity.icon),
      notes: Value(entity.notes),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }
}
