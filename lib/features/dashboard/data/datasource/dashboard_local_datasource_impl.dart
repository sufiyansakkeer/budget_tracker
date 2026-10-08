import 'package:drift/drift.dart';

import '../../../../core/data/models/budget_model.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/entities/committed_spending.dart';
import '../../domain/entities/recent_expense_entity.dart';
import 'dashboard_local_datasource.dart';

class DashboardLocalDataSourceImpl implements DashboardLocalDataSource {
  final AppDatabase database;

  DashboardLocalDataSourceImpl({required this.database});

  @override
  Future<List<RecentExpenseEntity>> getRecentExpenses({
    int limit = 5,
    DateTime? referenceDate,
    String? budgetId,
  }) async {
    final date = referenceDate ?? DateTime.now();

    // Resolve the budget period (used to scope recent expenses). When a budget
    // id is provided, we look up its start/end dates so recent expenses are
    // scoped to the budget's custom period, NOT the calendar month.
    DateTime? periodStart;
    DateTime? periodEnd;

    if (budgetId != null && budgetId.isNotEmpty) {
      final budget = await _getBudget(budgetId);
      if (budget != null) {
        periodStart = DateTime(
          budget.startDate.year,
          budget.startDate.month,
          budget.startDate.day,
        );
        periodEnd = DateTime(
          budget.endDate.year,
          budget.endDate.month,
          budget.endDate.day,
          23,
          59,
          59,
          999,
        );
      }
    }

    // Fall back to the current calendar month only when there is no budget.
    final start = periodStart ?? DateTime(date.year, date.month, 1);
    final end =
        periodEnd ?? DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

    final query = database.select(database.expenses);

    if (budgetId != null && budgetId.isNotEmpty) {
      query.where(
        (expense) =>
            expense.budgetId.equals(budgetId) &
            expense.date.isBiggerOrEqualValue(start) &
            expense.date.isSmallerOrEqualValue(end),
      );
    } else {
      query.where(
        (expense) =>
            expense.date.isBiggerOrEqualValue(start) &
            expense.date.isSmallerOrEqualValue(end),
      );
    }

    query
      ..orderBy([(expense) => OrderingTerm.desc(expense.date)])
      ..limit(limit);

    final expenses = await query.get();

    if (expenses.isEmpty) return [];

    final categoryIds = expenses.map((e) => e.categoryId).toSet();
    final categories = await (database.select(
      database.categories,
    )..where((cat) => cat.id.isIn(categoryIds))).get();

    final categoryMap = {for (var cat in categories) cat.id: cat};

    return expenses.map((expense) {
      final category = categoryMap[expense.categoryId];
      return RecentExpenseEntity(
        id: expense.id,
        amount: expense.amount,
        categoryId: expense.categoryId,
        categoryName: category?.name ?? 'Unknown',
        categoryIcon: category?.icon ?? 'help_outline',
        categoryColorHex: category?.colorHex ?? '#8395A7',
        note: expense.note,
        date: expense.date,
        createdAt: expense.createdAt,
      );
    }).toList();
  }

  @override
  Future<Map<String, CommittedSpending>> getCommittedSpending({
    required List<BudgetEntity> budgets,
    required DateTime today,
  }) async {
    final todayStart = _startOfDay(today);
    final todayEnd = _endOfDay(today);
    final result = <String, CommittedSpending>{};
    for (final budget in budgets) {
      final start = _startOfDay(budget.startDate);
      final end = _endOfDay(budget.endDate);
      final periodTotal = await _committedSum(budget.id, start, end);
      // Today's bounds are whole days, so inside the period they are already
      // inside the period's bounds; outside it there is nothing to count.
      final todayInPeriod =
          !todayStart.isBefore(start) && !todayStart.isAfter(end);
      final todayTotal = todayInPeriod && periodTotal != 0
          ? await _committedSum(budget.id, todayStart, todayEnd)
          : 0.0;
      result[budget.id] = CommittedSpending(
        periodTotal: periodTotal,
        todayTotal: todayTotal,
      );
    }
    return result;
  }

  /// SUM of a budget's committed expenses (`bill_id` set) in [start, end],
  /// in SQL over `index_expenses_budget_date`.
  Future<double> _committedSum(
    String budgetId,
    DateTime start,
    DateTime end,
  ) async {
    final sum = database.expenses.amount.sum();
    final query = database.selectOnly(database.expenses)
      ..addColumns([sum])
      ..where(
        database.expenses.budgetId.equals(budgetId) &
            database.expenses.billId.isNotNull() &
            database.expenses.date.isBiggerOrEqualValue(start) &
            database.expenses.date.isSmallerOrEqualValue(end),
      );
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  Future<BudgetEntity?> _getBudget(String id) async {
    final query = database.select(database.budgets)
      ..where((budget) => budget.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return BudgetModel.toEntity(row);
  }
}
