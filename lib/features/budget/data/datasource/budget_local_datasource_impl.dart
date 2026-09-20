import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/data/models/budget_model.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/entities/budget_filter.dart';
import '../../domain/entities/monthly_statistics_entity.dart';
import 'budget_local_datasource.dart';
import '../../../../core/constants/preference_keys.dart';

class BudgetLocalDataSourceImpl implements BudgetLocalDataSource {
  final AppDatabase database;
  final SharedPreferences sharedPreferences;

  BudgetLocalDataSourceImpl({
    required this.database,
    required this.sharedPreferences,
  });

  @override
  Future<String?> getActiveBudgetId() async {
    return sharedPreferences.getString(PreferenceKeys.activeBudgetId);
  }

  @override
  Future<void> setActiveBudgetId(String budgetId) async {
    await sharedPreferences.setString(PreferenceKeys.activeBudgetId, budgetId);
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
    // Delete associated expenses first, then the budget — atomically.
    await database.transaction(() async {
      await (database.delete(
        database.expenses,
      )..where((expense) => expense.budgetId.equals(id))).go();
      await (database.delete(
        database.budgets,
      )..where((budget) => budget.id.equals(id))).go();
    });
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
      // A duplicate starts with no expenses, so its remaining amount is the
      // full budget amount rather than the source's stored remaining.
      remainingAmount: source.monthlyAmount,
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

    final (:total, :count) = await _sumAndCount(
      budgetId,
      start: _startOfDay(budget.startDate),
      end: _endOfDay(budget.endDate),
    );
    if (count == 0) {
      return MonthlyStatisticsEntity.empty;
    }

    final (total: todaySpending, count: _) = await _sumAndCount(
      budgetId,
      start: _startOfDay(referenceDate),
      end: _endOfDay(referenceDate),
    );

    return MonthlyStatisticsEntity(
      totalSpent: total,
      expenseCount: count,
      todaySpending: todaySpending,
    );
  }

  /// SUM/COUNT of a budget's expenses in [start, end], computed in SQL so a
  /// budget with thousands of expenses never loads them all into memory.
  /// Served by `index_expenses_budget_date`.
  Future<({double total, int count})> _sumAndCount(
    String budgetId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final sum = database.expenses.amount.sum();
    final count = database.expenses.id.count();
    final query = database.selectOnly(database.expenses)
      ..addColumns([sum, count])
      ..where(
        database.expenses.budgetId.equals(budgetId) &
            database.expenses.date.isBiggerOrEqualValue(start) &
            database.expenses.date.isSmallerOrEqualValue(end),
      );
    final row = await query.getSingle();
    return (total: row.read(sum) ?? 0, count: row.read(count) ?? 0);
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    // One indexed SUM. Going through getBudgetStatistics would re-read the
    // budget row and sum the whole period as well, just to discard both —
    // and this is called once per budget on every dashboard load, every
    // widget refresh and every notification reschedule.
    final date = referenceDate ?? DateTime.now();
    final (:total, count: _) = await _sumAndCount(
      budgetId,
      start: _startOfDay(date),
      end: _endOfDay(date),
    );
    return total;
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
    final (:total, count: _) = await _sumAndCount(
      budgetId,
      start: _startOfDay(startDate),
      end: _endOfDay(endDate),
    );
    return total;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) {
    return database.transaction(action);
  }
}
