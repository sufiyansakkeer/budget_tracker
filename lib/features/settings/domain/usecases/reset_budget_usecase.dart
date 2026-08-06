import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../entities/settings_failure.dart';

/// Provides budget management actions: reset current month's budget and
/// reset the current month's expenses.
class ResetBudgetUseCase {
  final AppDatabase _database;

  ResetBudgetUseCase({required AppDatabase database}) : _database = database;

  /// Resets the budget amount for the current month to [newAmount].
  ///
  /// Preserves existing expenses. Returns the updated budget id.
  Future<SettingsResult<String>> resetBudgetAmount(double newAmount) async {
    if (newAmount <= 0) {
      return const SettingsError(
        SettingsFailure(
          type: SettingsErrorType.invalidData,
          message: 'Budget amount must be greater than zero.',
        ),
      );
    }

    final now = DateTime.now();
    final existing =
        await (_database.select(_database.budgets)..where(
              (b) => b.month.equals(now.month) & b.year.equals(now.year),
            ))
            .getSingleOrNull();

    try {
      if (existing == null) {
        final id = const Uuid().v4();
        await _database
            .into(_database.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: id,
                monthlyAmount: newAmount,
                remainingAmount: newAmount,
                currency: 'INR',
                month: now.month,
                year: now.year,
              ),
            );
        return SettingsSuccess(id);
      }

      await (_database.update(_database.budgets)
            ..where((b) => b.month.equals(now.month) & b.year.equals(now.year)))
          .write(
            BudgetsCompanion(
              monthlyAmount: Value(newAmount),
              remainingAmount: Value(newAmount),
              updatedAt: Value(DateTime.now()),
            ),
          );
      return SettingsSuccess(existing.id);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.saveFailure,
          message: 'Failed to reset budget: ${e.toString()}',
        ),
      );
    }
  }

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
}
