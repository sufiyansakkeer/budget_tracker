import 'package:uuid/uuid.dart';

import '../../../../core/domain/entities/budget_entity.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../entities/settings_failure.dart';

/// Budget maintenance actions exposed from Settings: change the active
/// budget's amount and start a fresh period.
///
/// Everything goes through [BudgetRepository] so the stored remaining amount
/// is recomputed by the repository (never by hand here) and the active-budget
/// preference has exactly one owner.
class ResetBudgetUseCase {
  final BudgetRepository _repository;

  /// Length of the period created by [resetCurrentMonth] (inclusive of the
  /// start day, so 31 calendar days).
  static const Duration newPeriodLength = Duration(days: 30);

  static const String _defaultName = 'Personal Budget';
  static const String _defaultCurrency = 'INR';

  ResetBudgetUseCase({required BudgetRepository repository})
    : _repository = repository;

  /// Sets the active budget's total amount to [newAmount].
  ///
  /// Existing expenses are preserved; the repository recomputes the remaining
  /// amount from them. When no budget exists yet, a default 31-day budget is
  /// created and made active. Returns the affected budget id.
  Future<SettingsResult<String>> resetBudgetAmount(double newAmount) async {
    if (newAmount <= 0) {
      return const SettingsError(
        SettingsFailure(
          type: SettingsErrorType.invalidData,
          message: 'Budget amount must be greater than zero.',
        ),
      );
    }

    try {
      final existing = await _activeOrLatestBudget();
      final now = DateTime.now();

      if (existing == null) {
        final budget = _newBudget(
          amount: newAmount,
          currency: _defaultCurrency,
          now: now,
        );
        await _repository.createBudget(budget);
        await _repository.setActiveBudgetId(budget.id);
        return SettingsSuccess(budget.id);
      }

      await _repository.updateBudget(
        existing.copyWith(monthlyAmount: newAmount, updatedAt: now),
      );
      return SettingsSuccess(existing.id);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.saveFailure,
          message: 'Failed to reset budget: $e',
        ),
      );
    }
  }

  /// Archives the active budget and creates a fresh period starting today
  /// with the same name, amount and currency, then makes it active.
  ///
  /// Archive + create run in one transaction, so exactly one new budget is
  /// created or nothing changes. Returns the new budget id.
  Future<SettingsResult<String>> resetCurrentMonth() async {
    try {
      final existing = await _activeOrLatestBudget();
      final now = DateTime.now();
      final budget = _newBudget(
        name: existing?.name ?? _defaultName,
        amount: existing?.monthlyAmount ?? 0,
        currency: existing?.currency ?? _defaultCurrency,
        color: existing?.color,
        icon: existing?.icon,
        now: now,
      );

      await _repository.transaction(() async {
        if (existing != null) {
          await _repository.setBudgetArchived(existing.id, archived: true);
        }
        await _repository.createBudget(budget);
      });

      // Only after the transaction committed.
      await _repository.setActiveBudgetId(budget.id);
      return SettingsSuccess(budget.id);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.saveFailure,
          message: 'Failed to reset month: $e',
        ),
      );
    }
  }

  /// The active budget, or — when the stored id is stale — the budget with
  /// the most recent start date.
  Future<BudgetEntity?> _activeOrLatestBudget() async {
    final active = await _repository.getActiveBudget();
    if (active != null) return active;
    final all = await _repository.getAllBudgets();
    if (all.isEmpty) return null;
    final sorted = [...all]..sort((a, b) => b.startDate.compareTo(a.startDate));
    return sorted.first;
  }

  BudgetEntity _newBudget({
    String name = _defaultName,
    required double amount,
    required String currency,
    String? color,
    String? icon,
    required DateTime now,
  }) {
    final start = DateTime(now.year, now.month, now.day);
    return BudgetEntity(
      id: const Uuid().v4(),
      name: name,
      monthlyAmount: amount,
      remainingAmount: amount,
      currency: currency,
      startDate: start,
      endDate: start.add(newPeriodLength),
      color: color,
      icon: icon,
      createdAt: now,
      updatedAt: now,
    );
  }
}
