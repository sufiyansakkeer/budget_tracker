import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/data/models/budget_model.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/entities/budget_filter.dart';
import '../../domain/entities/monthly_statistics_entity.dart';
import 'budget_local_datasource.dart';

class BudgetLocalDataSourceImpl implements BudgetLocalDataSource {
  static const String _activeBudgetIdKey = 'active_budget_id';

  final AppDatabase database;
  final SharedPreferences sharedPreferences;

  BudgetLocalDataSourceImpl({
    required this.database,
    required this.sharedPreferences,
  });

  @override
  Future<String?> getActiveBudgetId() async {
    return sharedPreferences.getString(_activeBudgetIdKey);
  }

  @override
  Future<void> setActiveBudgetId(String budgetId) async {
    await sharedPreferences.setString(_activeBudgetIdKey, budgetId);
  }

  @override
  Future<BudgetEntity?> getBudgetById(String id) async {
    final query = database.select(database.budgets)
      ..where((budget) => budget.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return BudgetModel.toEntity(row);
  }

  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async {
    final query = database.select(database.budgets);

    if (options != null) {
      switch (options.filter) {
        case BudgetFilter.active:
          query.where((budget) => budget.isArchived.equals(false));
          break;
        case BudgetFilter.archived:
          query.where((budget) => budget.isArchived.equals(true));
          break;
        case BudgetFilter.all:
          break;
      }

      if (options.searchQuery != null && options.searchQuery!.isNotEmpty) {
        final search = options.searchQuery!.toLowerCase();
        query.where((budget) => budget.name.lower().contains(search));
      }
    }

    query.orderBy([(budget) => OrderingTerm.desc(budget.startDate)]);

    final rows = await query.get();
    return rows.map(BudgetModel.toEntity).toList();
  }

  @override
  Future<BudgetEntity> createBudget(BudgetEntity budget) async {
    await database
        .into(database.budgets)
        .insert(BudgetModel.toCompanion(budget));
    return budget;
  }

  @override
  Future<BudgetEntity> updateBudget(BudgetEntity budget) async {
    await (database.update(database.budgets)
          ..where((b) => b.id.equals(budget.id)))
        .write(BudgetModel.toCompanion(budget));
    return budget;
  }

  @override
  Future<void> deleteBudget(String id) async {
    // Delete associated expenses first, then the budget.
    await (database.delete(
      database.expenses,
    )..where((expense) => expense.budgetId.equals(id))).go();
    await (database.delete(
      database.budgets,
    )..where((budget) => budget.id.equals(id))).go();
  }

  @override
  Future<BudgetEntity> setBudgetArchived(
    String id, {
    required bool archived,
  }) async {
    final now = DateTime.now();
    await (database.update(
      database.budgets,
    )..where((budget) => budget.id.equals(id))).write(
      BudgetsCompanion(isArchived: Value(archived), updatedAt: Value(now)),
    );
    final updated = await getBudgetById(id);
    if (updated == null) {
      throw StateError('Budget not found after archive update: $id');
    }
    return updated;
  }

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final source = await getBudgetById(id);
    if (source == null) {
      throw StateError('Source budget not found for duplication: $id');
    }

    final now = DateTime.now();
    final duplicate = BudgetEntity(
      id: _newId(),
      name: newName,
      monthlyAmount: source.monthlyAmount,
      remainingAmount: source.remainingAmount,
      currency: source.currency,
      startDate: startDate ?? source.startDate,
      endDate: endDate ?? source.endDate,
      isArchived: false,
      color: source.color,
      icon: source.icon,
      notes: source.notes,
      createdAt: now,
      updatedAt: now,
    );

    await database
        .into(database.budgets)
        .insert(BudgetModel.toCompanion(duplicate));
    return duplicate;
  }

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    required DateTime referenceDate,
  }) async {
    final budget = await getBudgetById(budgetId);
    if (budget == null) {
      return MonthlyStatisticsEntity.empty;
    }

    final start = DateTime(
      budget.startDate.year,
      budget.startDate.month,
      budget.startDate.day,
    );
    final end = DateTime(
      budget.endDate.year,
      budget.endDate.month,
      budget.endDate.day,
      23,
      59,
      59,
      999,
    );

    final expenses =
        await (database.select(database.expenses)..where(
              (expense) =>
                  expense.budgetId.equals(budgetId) &
                  expense.date.isBiggerOrEqualValue(start) &
                  expense.date.isSmallerOrEqualValue(end),
            ))
            .get();

    if (expenses.isEmpty) {
      return MonthlyStatisticsEntity.empty;
    }

    final totalSpent = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    final todayStart = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final todaySpending = expenses
        .where(
          (expense) =>
              !expense.date.isBefore(todayStart) &&
              !expense.date.isAfter(todayEnd),
        )
        .fold<double>(0, (sum, expense) => sum + expense.amount);

    return MonthlyStatisticsEntity(
      totalSpent: totalSpent,
      expenseCount: expenses.length,
      todaySpending: todaySpending,
    );
  }

  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    final date = referenceDate ?? DateTime.now();
    final stats = await getBudgetStatistics(budgetId, referenceDate: date);
    return stats.todaySpending;
  }

  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    final budget = await getBudgetById(budgetId);
    if (budget == null) return 1;

    final date = referenceDate ?? DateTime.now();
    if (date.isAfter(budget.endDate)) return 0;

    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(
      budget.endDate.year,
      budget.endDate.month,
      budget.endDate.day,
    );
    return end.difference(start).inDays + 1;
  }

  String _newId() {
    return 'budget_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    final expenses =
        await (database.select(database.expenses)..where(
              (expense) =>
                  expense.budgetId.equals(budgetId) &
                  expense.date.isBiggerOrEqualValue(start) &
                  expense.date.isSmallerOrEqualValue(end),
            ))
            .get();

    return expenses.fold<double>(0, (sum, e) => sum + e.amount);
  }
}
