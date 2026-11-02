import '../../../expenses/domain/entities/expense_entity.dart';
import '../../domain/entities/pay_later_tab.dart';
import '../../domain/entities/payment_allocation.dart';
import '../../domain/entities/tab_payment.dart';
import '../../domain/services/pay_later_allocator.dart';

abstract class PayLaterLocalDataSource {
  /// Runs [action] in a database transaction; a throw rolls everything back.
  /// Joins an enclosing transaction on the same database.
  Future<T> transaction<T>(Future<T> Function() action);

  Future<void> createTab(PayLaterTab tab);
  Future<void> updateTab(PayLaterTab tab);

  /// Throws (foreign key) when the tab has purchases or payments.
  Future<void> deleteTab(String id);
  Future<PayLaterTab?> getTab(String id);
  Future<List<PayLaterTab>> getTabs();
  Future<bool> tabHasActivity(String tabId);

  Future<void> linkExpense({required String expenseId, required String tabId});
  Future<void> unlinkExpense(String expenseId);
  Future<String?> tabIdForExpense(String expenseId);

  /// Linked expenses, oldest first: date, then time, then createdAt.
  Future<List<ExpenseEntity>> purchasesOf(String tabId);
  Future<int> purchasesInBudget(String budgetId);
  Future<List<String>> tabIdsWithPurchasesInBudget(String budgetId);
  Future<List<String>> tabIdsWithActivity();

  Future<void> createPayment(TabPayment payment);
  Future<void> updatePayment(TabPayment payment);
  Future<void> deletePayment(String id);
  Future<TabPayment?> getPayment(String id);
  Future<List<TabPayment>> paymentsOf(String tabId);
  Future<List<PaymentAllocation>> allocationsOf(String tabId);

  /// Applies deletes, then updates, then inserts.
  Future<void> applyDiff(AllocationDiff diff);
}
