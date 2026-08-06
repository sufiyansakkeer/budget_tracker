import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../entities/settings_failure.dart';

/// Provides month management actions: reset current month's budget and
/// reset the current month's expenses.
class ResetMonthUseCase {
  final AppDatabase _database;

  ResetMonthUseCase({required AppDatabase database}) : _database = database;

  /// Archives the current month's data by keeping it in the database and
  /// creating a fresh budget for the next month (or the current month if no
  /// budget exists yet).
  ///
  /// Returns the new budget id.
  Future<SettingsResult<String>> resetCurrentMonth() async {
    final now = DateTime.now();
    final next = DateTime(
      now.month == 12 ? now.year + 1 : now.year,
      now.month == 12 ? 1 : now.month + 1,
      1,
    );

    try {
      final id = const Uuid().v4();
      await _database
          .into(_database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: id,
              monthlyAmount: 0,
              remainingAmount: 0,
              currency: 'INR',
              month: next.month,
              year: next.year,
            ),
          );
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

  /// Resets the current month's expenses by archiving them and creating a fresh
  /// expense tracking for the next month.
  ///
  /// Returns the number of archived expenses.
  Future<SettingsResult<int>> resetCurrentMonthExpenses() async {
    final now = DateTime.now();
    final next = DateTime(
      now.month == 12 ? now.year + 1 : now.year,
      now.month == 12 ? 1 : now.month + 1,
      1,
    );

    try {
      // Get all expenses for the current month
      final currentMonthExpenses = await (_database.select(_database.expenses)
            ..where((e) => e.date.month.equals(now.month) & e.date.year.equals(now.year)))
            .get();

      final archivedCount = currentMonthExpenses.length;

      // Update expense dates to next month
      for (final expense in currentMonthExpenses) {
        await (_database.update(_database.expenses)
              ..where((e) => e.id.equals(expense.id)))
            .write(
              ExpensesCompanion(
                date: Value(next),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }

      return SettingsSuccess(archivedCount);
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