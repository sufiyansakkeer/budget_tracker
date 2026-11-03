import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/payment_allocation.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/repository/pay_later_repository.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_allocator.dart';

/// A [PayLaterRepository] held in maps, so widget tests can run the real
/// Pay Later use cases without a database. [transaction] just runs the
/// action (no rollback).
class MemoryPayLaterRepository implements PayLaterRepository {
  final Map<String, PayLaterTab> tabs = {};

  /// Linked expenses by tab id.
  final Map<String, List<ExpenseEntity>> purchases = {};
  final Map<String, TabPayment> payments = {};
  final Map<String, PaymentAllocation> allocations = {};

  /// Every payment ever created, in order (a double record shows up here).
  final List<String> createdPaymentIds = [];

  /// Makes [getTab] throw, as when the database can't be read.
  Object? readError;

  void addTab(PayLaterTab tab) => tabs[tab.id] = tab;

  void addPurchase(String tabId, ExpenseEntity expense) =>
      purchases.putIfAbsent(tabId, () => []).add(expense);

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();

  @override
  Future<void> createTab(PayLaterTab tab) async => tabs[tab.id] = tab;

  @override
  Future<void> updateTab(PayLaterTab tab) async => tabs[tab.id] = tab;

  @override
  Future<void> deleteTab(String id) async {
    if (await tabHasActivity(id)) throw StateError('Tab $id is used');
    tabs.remove(id);
  }

  @override
  Future<PayLaterTab?> getTab(String id) async {
    final error = readError;
    if (error != null) throw error;
    return tabs[id];
  }

  @override
  Future<List<PayLaterTab>> getTabs() async => tabs.values.toList();

  @override
  Future<bool> tabHasActivity(String tabId) async =>
      (purchases[tabId]?.isNotEmpty ?? false) ||
      payments.values.any((p) => p.tabId == tabId);

  @override
  Future<void> linkExpense({
    required String expenseId,
    required String tabId,
  }) => throw UnimplementedError();

  @override
  Future<void> unlinkExpense(String expenseId) => throw UnimplementedError();

  @override
  Future<String?> tabIdForExpense(String expenseId) async {
    for (final MapEntry(key: tabId, value: list) in purchases.entries) {
      if (list.any((e) => e.id == expenseId)) return tabId;
    }
    return null;
  }

  @override
  Future<List<ExpenseEntity>> purchasesOf(String tabId) async {
    final list = [...?purchases[tabId]];
    list.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  @override
  Future<int> purchasesInBudget(String budgetId) async => 0;

  @override
  Future<List<String>> tabIdsWithPurchasesInBudget(String budgetId) async =>
      const [];

  @override
  Future<List<String>> tabIdsWithActivity() async => [
    for (final id in tabs.keys)
      if (await tabHasActivity(id)) id,
  ];

  @override
  Future<void> createPayment(TabPayment payment) async {
    if (payments.containsKey(payment.id)) {
      throw StateError('UNIQUE constraint failed: ${payment.id}');
    }
    payments[payment.id] = payment;
    createdPaymentIds.add(payment.id);
  }

  @override
  Future<void> updatePayment(TabPayment payment) async =>
      payments[payment.id] = payment;

  @override
  Future<void> deletePayment(String id) async {
    payments.remove(id);
    allocations.removeWhere((_, a) => a.paymentId == id);
  }

  @override
  Future<TabPayment?> getPayment(String id) async => payments[id];

  @override
  Future<List<TabPayment>> paymentsOf(String tabId) async => [
    for (final p in payments.values)
      if (p.tabId == tabId) p,
  ];

  @override
  Future<List<PaymentAllocation>> allocationsOf(String tabId) async {
    final ids = {for (final p in await paymentsOf(tabId)) p.id};
    return [
      for (final a in allocations.values)
        if (ids.contains(a.paymentId)) a,
    ];
  }

  @override
  Future<void> applyDiff(AllocationDiff diff) async {
    for (final id in diff.deletes) {
      allocations.remove(id);
    }
    for (final MapEntry(key: id, value: amount) in diff.updates.entries) {
      allocations[id] = allocations[id]!.copyWith(amount: amount);
    }
    for (final a in diff.inserts) {
      allocations[a.id] = a;
    }
  }
}
