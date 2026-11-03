import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/currency/money_math.dart';
import '../entities/budget_filter.dart';
import '../repository/budget_repository.dart';
import '../../../pay_later/domain/usecases/reconcile_tab_usecase.dart';

/// A budget's currency can't change while it holds purchases on Pay later
/// tabs: a tab and its purchases share one currency (spec §2), so the tab's
/// sum would silently mix currencies.
class BudgetCurrencyLockedException implements Exception {
  /// How many purchases on tabs the budget holds.
  final int tabPurchases;

  /// The budget's (and those tabs') currency.
  final String currency;

  const BudgetCurrencyLockedException({
    required this.tabPurchases,
    required this.currency,
  });

  /// Why, and what to do instead.
  String get message => tabPurchases == 1
      ? '1 purchase in this budget is on a Pay later tab in $currency. Move '
            'it to another $currency budget or take it off its tab first.'
      : '$tabPurchases purchases in this budget are on Pay later tabs in '
            '$currency. Move them to another $currency budget or take them '
            'off their tab first.';

  @override
  String toString() => 'BudgetCurrencyLockedException: $message';
}

/// Aggregates CRUD, archive, duplicate, and active-budget operations for the
/// multi-budget system. Screens use this single use case to avoid proliferating
/// tiny use-case classes.
class ManageBudgetUseCase {
  final BudgetRepository repository;

  /// Deleting a budget deletes its expenses, which can be purchases on Pay
  /// later tabs; those tabs are reconciled in the same transaction.
  final ReconcileTabUseCase reconcileTabs;

  ManageBudgetUseCase({required this.repository, required this.reconcileTabs});

  Future<BudgetEntity> create(BudgetEntity budget) {
    return repository.createBudget(budget);
  }

  /// Saves [budget]. A currency change is refused with a
  /// [BudgetCurrencyLockedException] while the budget holds purchases on
  /// Pay later tabs; every other edit (and any edit of a budget with none)
  /// saves as before.
  Future<BudgetEntity> update(BudgetEntity budget) async {
    final stored = await repository.getBudgetById(budget.id);
    if (stored != null && stored.currency != budget.currency) {
      final count = await reconcileTabs.countPurchasesInBudget(budget.id);
      if (count > 0) {
        throw BudgetCurrencyLockedException(
          tabPurchases: count,
          currency: stored.currency,
        );
      }
    }
    return repository.updateBudget(budget);
  }

  /// Deletes the budget and every expense in it. Pay later tabs that had a
  /// purchase in it are reconciled in the same transaction, so payment
  /// money moves to other purchases or stays as credit, or nothing at all
  /// is deleted.
  Future<void> delete(String id) {
    return reconcileTabs.aroundBudgetDelete(
      id,
      () => repository.deleteBudget(id),
    );
  }

  /// How many purchases on Pay later tabs the budget holds, for the delete
  /// confirmation. Throws on a database failure.
  Future<int> tabPurchasesIn(String id) {
    return reconcileTabs.countPurchasesInBudget(id);
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
