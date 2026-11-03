import '../../../expenses/domain/entities/expense_entity.dart';
import '../../domain/entities/pay_later_tab.dart';
import '../../domain/entities/payment_allocation.dart';
import '../../domain/entities/tab_payment.dart';
import '../../domain/repository/pay_later_repository.dart';
import '../../domain/services/pay_later_allocator.dart';
import '../datasource/pay_later_local_datasource.dart';

class PayLaterRepositoryImpl implements PayLaterRepository {
  final PayLaterLocalDataSource localDataSource;

  PayLaterRepositoryImpl({required this.localDataSource});

  @override
  Future<T> transaction<T>(Future<T> Function() action) {
    return localDataSource.transaction(action);
  }

  @override
  Future<void> createTab(PayLaterTab tab) {
    return localDataSource.createTab(tab);
  }

  @override
  Future<void> updateTab(PayLaterTab tab) {
    return localDataSource.updateTab(tab);
  }

  @override
  Future<void> deleteTab(String id) {
    return localDataSource.deleteTab(id);
  }

  @override
  Future<PayLaterTab?> getTab(String id) {
    return localDataSource.getTab(id);
  }

  @override
  Future<List<PayLaterTab>> getTabs() {
    return localDataSource.getTabs();
  }

  @override
  Future<bool> tabHasActivity(String tabId) {
    return localDataSource.tabHasActivity(tabId);
  }

  @override
  Future<void> linkExpense({required String expenseId, required String tabId}) {
    return localDataSource.linkExpense(expenseId: expenseId, tabId: tabId);
  }

  @override
  Future<void> unlinkExpense(String expenseId) {
    return localDataSource.unlinkExpense(expenseId);
  }

  @override
  Future<String?> tabIdForExpense(String expenseId) {
    return localDataSource.tabIdForExpense(expenseId);
  }

  @override
  Future<List<ExpenseEntity>> purchasesOf(String tabId) {
    return localDataSource.purchasesOf(tabId);
  }

  @override
  Future<int> purchasesInBudget(String budgetId) {
    return localDataSource.purchasesInBudget(budgetId);
  }

  @override
  Future<List<String>> tabIdsWithPurchasesInBudget(String budgetId) {
    return localDataSource.tabIdsWithPurchasesInBudget(budgetId);
  }

  @override
  Future<List<String>> tabIdsWithActivity() {
    return localDataSource.tabIdsWithActivity();
  }

  @override
  Future<void> createPayment(TabPayment payment) {
    return localDataSource.createPayment(payment);
  }

  @override
  Future<void> updatePayment(TabPayment payment) {
    return localDataSource.updatePayment(payment);
  }

  @override
  Future<void> deletePayment(String id) {
    return localDataSource.deletePayment(id);
  }

  @override
  Future<TabPayment?> getPayment(String id) {
    return localDataSource.getPayment(id);
  }

  @override
  Future<List<TabPayment>> paymentsOf(String tabId) {
    return localDataSource.paymentsOf(tabId);
  }

  @override
  Future<List<PaymentAllocation>> allocationsOf(String tabId) {
    return localDataSource.allocationsOf(tabId);
  }

  @override
  Future<void> applyDiff(AllocationDiff diff) {
    return localDataSource.applyDiff(diff);
  }
}
