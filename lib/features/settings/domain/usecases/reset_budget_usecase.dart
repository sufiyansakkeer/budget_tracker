import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../entities/settings_failure.dart';

/// Provides budget management actions: reset the active budget's amount and
/// archive the active budget.
class ResetBudgetUseCase {
  final AppDatabase _database;
  final SharedPreferences _sharedPreferences;

  static const String _activeBudgetIdKey = 'active_budget_id';

  ResetBudgetUseCase({
    required AppDatabase database,
    required SharedPreferences sharedPreferences,
  }) : _database = database,
       _sharedPreferences = sharedPreferences;

  /// Resets the active budget's amount to [newAmount].
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

    final existing = await _activeBudgetRow();

    try {
      if (existing == null) {
        final id = const Uuid().v4();
        final now = DateTime.now();
        await _database
            .into(_database.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: id,
                name: 'Personal Budget',
                monthlyAmount: newAmount,
                remainingAmount: newAmount,
                currency: 'INR',
                startDate: DateTime(now.year, now.month, now.day),
                endDate: DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).add(const Duration(days: 30)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        // Persist the new budget as active.
        await _sharedPreferences.setString(_activeBudgetIdKey, id);
        return SettingsSuccess(id);
      }

      await (_database.update(
        _database.budgets,
      )..where((b) => b.id.equals(existing.id))).write(
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

  /// Archives the active budget and creates a fresh default budget. Returns
  /// the new budget id.
  Future<SettingsResult<String>> resetCurrentMonth() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 30));

    try {
      final existing = await _activeBudgetRow();
      if (existing != null) {
        await (_database.update(
          _database.budgets,
        )..where((b) => b.id.equals(existing.id))).write(
          BudgetsCompanion(
            isArchived: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      final id = const Uuid().v4();
      await _database
          .into(_database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: id,
              name: 'Personal Budget',
              monthlyAmount: 0,
              remainingAmount: 0,
              currency: 'INR',
              startDate: start,
              endDate: end,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      // Persist the newly created budget as active.
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

  Future<Budget?> _activeBudgetRow() async {
    final activeId = _sharedPreferences.getString(_activeBudgetIdKey);
    if (activeId == null) return null;
    final row = await (_database.select(
      _database.budgets,
    )..where((b) => b.id.equals(activeId))).getSingleOrNull();
    if (row != null) return row;
    // Fall back to the most recent budget if the stored active id is stale.
    return (_database.select(
      _database.budgets,
    )..orderBy([(b) => OrderingTerm.desc(b.startDate)])).getSingleOrNull();
  }
}
