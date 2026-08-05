import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/data/models/budget_model.dart';
import '../../domain/entities/monthly_statistics_entity.dart';
import 'budget_local_datasource.dart';

class BudgetLocalDataSourceImpl implements BudgetLocalDataSource {
  final AppDatabase database;

  BudgetLocalDataSourceImpl({required this.database});

  @override
  Future<BudgetEntity?> getBudgetForMonth({
    required int month,
    required int year,
  }) async {
    final query = database.select(database.budgets)
      ..where(
        (budget) => budget.month.equals(month) & budget.year.equals(year),
      );

    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return BudgetModel.toEntity(row);
  }

  @override
  Future<MonthlyStatisticsEntity> getMonthlyStatistics({
    required int month,
    required int year,
    required DateTime referenceDate,
  }) async {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59, 999);

    final monthExpenses = await (database.select(database.expenses)
          ..where(
            (expense) =>
                expense.date.isBiggerOrEqualValue(monthStart) &
                expense.date.isSmallerOrEqualValue(monthEnd),
          ))
        .get();

    if (monthExpenses.isEmpty) {
      return MonthlyStatisticsEntity.empty;
    }

    final totalSpent = monthExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    final todayStart = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(
          const Duration(milliseconds: 1),
        );

    final todaySpending = monthExpenses
        .where(
          (expense) =>
              !expense.date.isBefore(todayStart) &&
              !expense.date.isAfter(todayEnd),
        )
        .fold<double>(0, (sum, expense) => sum + expense.amount);

    return MonthlyStatisticsEntity(
      totalSpent: totalSpent,
      expenseCount: monthExpenses.length,
      todaySpending: todaySpending,
    );
  }
}
