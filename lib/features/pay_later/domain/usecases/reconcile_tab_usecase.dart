import '../repository/pay_later_repository.dart';
import '../services/pay_later_allocator.dart';

/// Re-derives a tab's automatic allocations from its purchases and payments
/// (spec §5) and stores the difference.
class ReconcileTabUseCase {
  final PayLaterRepository _repository;

  ReconcileTabUseCase({required PayLaterRepository repository})
    : _repository = repository;

  /// Reconciles one tab. Does not open a transaction: the caller owns it, so
  /// the reconcile commits or rolls back with the write that prompted it.
  Future<void> call(String tabId) async {
    final tab = await _repository.getTab(tabId);
    if (tab == null) return;
    // Every row goes in: reconcile deletes allocations whose purchase or
    // payment is missing from its inputs.
    final diff = PayLaterAllocator(currency: tab.currency).reconcile(
      purchases: await _repository.purchasesOf(tabId),
      payments: await _repository.paymentsOf(tabId),
      allocations: await _repository.allocationsOf(tabId),
    );
    if (diff.isEmpty) return;
    await _repository.applyDiff(diff);
  }

  /// Reconciles every tab that has purchases or payments, one transaction
  /// per tab: each tab is atomic, and the start-up safety net never holds
  /// the database for every tab at once. Inside an enclosing transaction
  /// (restore) each one nests, so the whole run still rolls back with it.
  Future<void> all() async {
    for (final tabId in await _repository.tabIdsWithActivity()) {
      await _repository.transaction(() => call(tabId));
    }
  }

  /// Runs [delete], which deletes budget [budgetId] with its expenses, and
  /// reconciles every tab that had a purchase in it, in one transaction:
  /// the budget delete's own transaction nests inside it, so a failed
  /// reconcile rolls the delete back too (spec §5, "Delete a purchase").
  Future<T> aroundBudgetDelete<T>(
    String budgetId,
    Future<T> Function() delete,
  ) => _repository.transaction(() async {
    final touched = await _repository.tabIdsWithPurchasesInBudget(budgetId);
    final result = await delete();
    for (final tabId in touched) {
      await call(tabId);
    }
    return result;
  });

  /// How many purchases on Pay later tabs budget [budgetId] holds, for the
  /// budget delete confirmation. Throws on a database failure.
  Future<int> countPurchasesInBudget(String budgetId) =>
      _repository.purchasesInBudget(budgetId);
}
