import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/recent_expense_entity.dart';
import 'dashboard_local_datasource.dart';

class DashboardLocalDataSourceImpl implements DashboardLocalDataSource {
  final AppDatabase database;

  DashboardLocalDataSourceImpl({required this.database});

  @override
  Future<List<RecentExpenseEntity>> getRecentExpenses({
    int limit = 5,
    DateTime? referenceDate,
  }) async {
    final date = referenceDate ?? DateTime.now();
    final monthStart = DateTime(date.year, date.month, 1);
    final monthEnd = DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

    final expensesQuery = database.select(database.expenses)
      ..where(
        (expense) =>
            expense.date.isBiggerOrEqualValue(monthStart) &
            expense.date.isSmallerOrEqualValue(monthEnd),
      )
      ..orderBy([(expense) => OrderingTerm.desc(expense.date)])
      ..limit(limit);

    final expenses = await expensesQuery.get();

    if (expenses.isEmpty) return [];

    final categoryIds = expenses.map((e) => e.categoryId).toSet();
    final categories = await (database.select(database.categories)
          ..where((cat) => cat.id.isIn(categoryIds)))
        .get();

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
}
