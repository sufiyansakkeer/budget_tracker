import 'package:uuid/uuid.dart';

import '../../../../core/currency/money_math.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../bills/domain/repository/bill_repository.dart';
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
  final BillRepository _billRepository;
  final DateTime Function() _clock;

  /// Length of the period created by [resetCurrentMonth] (inclusive of the
  /// start day, so 31 calendar days).
  static const Duration newPeriodLength = Duration(days: 30);

  static const String _defaultName = 'Personal Budget';
  static const String _defaultCurrency = 'INR';

  ResetBudgetUseCase({
    required BudgetRepository repository,
    required BillRepository billRepository,
    DateTime Function()? clock,
  }) : _repository = repository,
       _billRepository = billRepository,
       _clock = clock ?? DateTime.now;

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
    if (!MoneyMath.isWithinLimit(newAmount)) {
      return const SettingsError(
        SettingsFailure(
          type: SettingsErrorType.invalidData,
          message:
              'Budget amount must be less than ${MoneyMath.maxAmountLabel}.',
        ),
      );
    }

    try {
      final existing = await _activeOrLatestBudget();
      final now = _clock();

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
  /// with the same name, amount, currency, kept-aside amount and savings
  /// goal, then makes it active. Unpaid bills linked to the archived budget
  /// are re-linked to the new one, so they keep being set aside.
  ///
  /// Archive + create + re-link run in one transaction, so exactly one new
  /// budget is created or nothing changes. Returns the new budget id.
  Future<SettingsResult<String>> resetCurrentMonth() async {
    try {
      final existing = await _activeOrLatestBudget();
      final now = _clock();
      final budget = _newBudget(
        name: existing?.name ?? _defaultName,
        amount: existing?.monthlyAmount ?? 0,
        currency: existing?.currency ?? _defaultCurrency,
        color: existing?.color,
        icon: existing?.icon,
        reservedAmount: existing?.reservedAmount,
        savingsTarget: existing?.savingsTarget,
        now: now,
      );

      await _repository.transaction(() async {
        if (existing != null) {
          await _repository.setBudgetArchived(existing.id, archived: true);
        }
        await _repository.createBudget(budget);
        if (existing != null) {
          await _relinkUnpaidBills(from: existing.id, to: budget.id, now: now);
        }
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

  /// Points every unpaid bill linked to budget [from] at budget [to]. Runs
  /// inside the caller's transaction (same database, so it nests).
  Future<void> _relinkUnpaidBills({
    required String from,
    required String to,
    required DateTime now,
  }) async {
    final bills = await _billRepository.getBills();
    for (final bill in bills) {
      if (bill.budgetId == from && !bill.isPaid) {
        await _billRepository.updateBill(
          bill.copyWith(budgetId: to, updatedAt: now),
        );
      }
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
    double? reservedAmount,
    double? savingsTarget,
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
      // Calendar arithmetic: adding a Duration across a DST change lands an
      // hour short of midnight, a day before the intended end date.
      endDate: DateTime(
        start.year,
        start.month,
        start.day + newPeriodLength.inDays,
      ),
      color: color,
      icon: icon,
      reservedAmount: reservedAmount,
      savingsTarget: savingsTarget,
      createdAt: now,
      updatedAt: now,
    );
  }
}
