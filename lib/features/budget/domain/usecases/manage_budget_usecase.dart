import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/currency/money_math.dart';
import '../entities/budget_filter.dart';
import '../repository/budget_repository.dart';

/// Aggregates CRUD, archive, duplicate, and active-budget operations for the
/// multi-budget system. Screens use this single use case to avoid proliferating
/// tiny use-case classes.
class ManageBudgetUseCase {
  final BudgetRepository repository;

  ManageBudgetUseCase({required this.repository});

  Future<BudgetEntity> create(BudgetEntity budget) {
    return repository.createBudget(budget);
  }

  Future<BudgetEntity> update(BudgetEntity budget) {
    return repository.updateBudget(budget);
  }

  Future<void> delete(String id) {
    return repository.deleteBudget(id);
  }

  Future<List<BudgetEntity>> getAll({BudgetQueryOptions? options}) {
    return repository.getAllBudgets(options: options);
  }

  Future<BudgetEntity?> getById(String id) {
    return repository.getBudgetById(id);
  }

  Future<BudgetEntity?> getActive() {
    return repository.getActiveBudget();
  }

  Future<BudgetEntity> archive(String id, {required bool archived}) {
    return repository.setBudgetArchived(id, archived: archived);
  }

  Future<BudgetEntity> duplicate(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return repository.duplicateBudget(
      id,
      newName: newName,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> setActive(String id) {
    return repository.setActiveBudgetId(id);
  }

  Future<String?> activeBudgetId() {
    return repository.getActiveBudgetId();
  }

  /// Validates budget input. Returns an error message or null if valid.
  String? validate(
    String name,
    double amount,
    DateTime startDate,
    DateTime endDate, {
    double? reservedAmount,
    double? savingsTarget,
  }) {
    if (name.trim().isEmpty) {
      return 'Budget name cannot be empty.';
    }
    if (amount <= 0) {
      return 'Budget amount must be greater than zero.';
    }
    if (!MoneyMath.isWithinLimit(amount)) {
      return 'Budget amount must be less than ${MoneyMath.maxAmountLabel}.';
    }
    if (!endDate.isAfter(startDate)) {
      return 'End date must be after the start date.';
    }
    return validateSetAside(reservedAmount, amount) ??
        validateSetAside(savingsTarget, amount);
  }

  /// Money kept aside, or a savings goal, for a budget of [budgetAmount].
  /// Null (not set) is fine.
  static String? validateSetAside(double? amount, double budgetAmount) {
    if (amount == null) return null;
    if (amount < 0) return "This can't be negative.";
    if (budgetAmount > 0 && amount > budgetAmount) {
      return "This can't be more than the budget amount.";
    }
    return null;
  }

  /// Whether money kept aside and the savings goal together take the whole
  /// budget, leaving nothing free to spend. Added in [currency]'s units:
  /// OMR 138.7 + 0.2 is 138.89999… in doubles, just short of 138.9.
  static bool setAsideTakesAll({
    required double budgetAmount,
    double? reserve,
    double? savings,
    required String currency,
  }) {
    if (budgetAmount <= 0) return false;
    final money = MoneyMath.forCurrency(currency);
    try {
      final set = money.sumUnits([reserve ?? 0, savings ?? 0]);
      return set > 0 && set >= money.toUnits(budgetAmount);
    } on ArgumentError {
      return false;
    }
  }
}
