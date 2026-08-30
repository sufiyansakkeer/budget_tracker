import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../entities/settings_failure.dart';

/// Provides month management actions: reset current month's budget and
/// reset the current month's expenses.
class ResetMonthUseCase {
  final AppDatabase _database;
  final SharedPreferences _sharedPreferences;

  static const String _activeBudgetIdKey = 'active_budget_id';

  ResetMonthUseCase({
    required AppDatabase database,
    required SharedPreferences sharedPreferences,
  }) : _database = database,
       _sharedPreferences = sharedPreferences;

  /// Archives the current active budget and creates a fresh default budget
  /// starting today with a custom date range (not bound to a calendar month).
  ///
  /// The entire operation runs inside a transaction so either both the
  /// archive and the new budget succeed, or neither does.
  ///
  /// Returns the new budget id.
  Future<SettingsResult<String>> resetCurrentMonth() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 30));

    try {
      final id = const Uuid().v4();

      // Archive the current active budget and create a fresh one atomically.
      await _database.transaction(() async {
        final activeId = _sharedPreferences.getString(_activeBudgetIdKey);
        if (activeId != null) {
          await (_database.update(
            _database.budgets,
          )..where((b) => b.id.equals(activeId))).write(
            BudgetsCompanion(
              isArchived: const Value(true),
              updatedAt: Value(now),
            ),
          );
        }

        await _database
            .into(_database.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: id,
                name: 'New Budget',
                monthlyAmount: 0,
                remainingAmount: 0,
                currency: 'INR',
                startDate: start,
                endDate: end,
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      });

      // Persist the newly created budget as active (only after success).
      await _sharedPreferences.setString(_activeBudgetIdKey, id);
      return SettingsSuccess(id);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.saveFailure,
          message: 'Failed to reset month: ${e.toString()}',
        ),
      );
    }
  }

  /// Resets the active budget's expenses by moving them to a fresh budget
  /// period. Returns the number of expenses moved.
  ///
  /// The entire operation runs inside a transaction so the new budget and
  /// expense reassignments are atomic.
  Future<SettingsResult<int>> resetCurrentMonthExpenses() async {
    final activeId = _sharedPreferences.getString(_activeBudgetIdKey);
    if (activeId == null) {
      return SettingsSuccess(0);
    }

    try {
      // Get all expenses for the active budget.
      final budgetExpenses = await (_database.select(
        _database.expenses,
      )..where((e) => e.budgetId.equals(activeId))).get();

      final count = budgetExpenses.length;

      // Create a fresh budget starting today and move the expenses there.
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 30));
      final newId = const Uuid().v4();

      await _database.transaction(() async {
        await _database
            .into(_database.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: newId,
                name: 'Monthly Budget',
                monthlyAmount: 0,
                remainingAmount: 0,
                currency: 'INR',
                startDate: start,
                endDate: end,
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        for (final expense in budgetExpenses) {
          await (_database.update(
            _database.expenses,
          )..where((e) => e.id.equals(expense.id))).write(
            ExpensesCompanion(
              budgetId: Value(newId),
              updatedAt: Value(now),
            ),
          );
        }
      });

      await _sharedPreferences.setString(_activeBudgetIdKey, newId);
      return SettingsSuccess(count);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.saveFailure,
          message: 'Failed to reset month expenses: ${e.toString()}',
        ),
      );
    }
  }
}
