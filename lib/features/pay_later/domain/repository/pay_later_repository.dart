import '../../../expenses/domain/entities/expense_entity.dart';
import '../entities/pay_later_tab.dart';
import '../entities/payment_allocation.dart';
import '../entities/tab_payment.dart';
import '../services/pay_later_allocator.dart';

abstract class PayLaterRepository {
  /// Runs [action] atomically; a throw rolls back every write inside. Joins
  /// an enclosing transaction on the same database.
  Future<T> transaction<T>(Future<T> Function() action);

  // Tabs
  Future<void> createTab(PayLaterTab tab);
  Future<void> updateTab(PayLaterTab tab);

  /// Throws when the tab has purchases or payments.
  Future<void> deleteTab(String id);
  Future<PayLaterTab?> getTab(String id);

  /// All tabs, archived included.
  Future<List<PayLaterTab>> getTabs();

  /// True when the tab has any linked purchase or payment.
  Future<bool> tabHasActivity(String tabId);

  // Links
  Future<void> linkExpense({required String expenseId, required String tabId});
  Future<void> unlinkExpense(String expenseId);
  Future<String?> tabIdForExpense(String expenseId);

  /// The tab's linked expenses, oldest first (date, time, createdAt).
  Future<List<ExpenseEntity>> purchasesOf(String tabId);
  Future<int> purchasesInBudget(String budgetId);
  Future<List<String>> tabIdsWithPurchasesInBudget(String budgetId);
  Future<List<String>> tabIdsWithActivity();

  // Payments and allocations
  Future<void> createPayment(TabPayment payment);
  Future<void> updatePayment(TabPayment payment);
  Future<void> deletePayment(String id);
  Future<TabPayment?> getPayment(String id);
  Future<List<TabPayment>> paymentsOf(String tabId);
  Future<List<PaymentAllocation>> allocationsOf(String tabId);

  /// Applies deletes, then updates, then inserts.
  Future<void> applyDiff(AllocationDiff diff);
}
