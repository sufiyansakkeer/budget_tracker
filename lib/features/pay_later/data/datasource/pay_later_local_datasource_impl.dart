import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../domain/entities/pay_later_tab.dart';
import '../../domain/entities/payment_allocation.dart';
import '../../domain/entities/tab_payment.dart';
import '../../domain/services/pay_later_allocator.dart';
import '../models/pay_later_models.dart';
import 'pay_later_local_datasource.dart';

class PayLaterLocalDataSourceImpl implements PayLaterLocalDataSource {
  final AppDatabase database;

  PayLaterLocalDataSourceImpl({required this.database});

  @override
  Future<T> transaction<T>(Future<T> Function() action) {
    return database.transaction(action);
  }

  @override
  Future<void> createTab(PayLaterTab tab) async {
    await database
        .into(database.payLaterAccounts)
        .insert(PayLaterModels.tabToCompanion(tab));
  }

  @override
  Future<void> updateTab(PayLaterTab tab) async {
    await (database.update(
      database.payLaterAccounts,
    )..where((t) => t.id.equals(tab.id))).write(
      PayLaterModels.tabToCompanion(tab).copyWith(id: const Value.absent()),
    );
  }

  @override
  Future<void> deleteTab(String id) async {
    await (database.delete(
      database.payLaterAccounts,
    )..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<PayLaterTab?> getTab(String id) async {
    final row = await (database.select(
      database.payLaterAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : PayLaterModels.tabToEntity(row);
  }

  @override
  Future<List<PayLaterTab>> getTabs() async {
    final rows =
        await (database.select(database.payLaterAccounts)..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    return rows.map(PayLaterModels.tabToEntity).toList();
  }

  @override
  Future<bool> tabHasActivity(String tabId) async {
    final entry =
        await (database.select(database.payLaterEntries)
              ..where((e) => e.accountId.equals(tabId))
              ..limit(1))
            .get();
    if (entry.isNotEmpty) return true;
    final payment =
        await (database.select(database.payLaterPayments)
              ..where((p) => p.accountId.equals(tabId))
              ..limit(1))
            .get();
    return payment.isNotEmpty;
  }

  @override
  Future<void> linkExpense({
    required String expenseId,
    required String tabId,
  }) async {
    await database
        .into(database.payLaterEntries)
        .insert(
          PayLaterEntriesCompanion.insert(
            expenseId: expenseId,
            accountId: tabId,
          ),
        );
  }

  @override
  Future<void> unlinkExpense(String expenseId) async {
    await (database.delete(
      database.payLaterEntries,
    )..where((e) => e.expenseId.equals(expenseId))).go();
  }

  @override
  Future<String?> tabIdForExpense(String expenseId) async {
    final row = await (database.select(
      database.payLaterEntries,
    )..where((e) => e.expenseId.equals(expenseId))).getSingleOrNull();
    return row?.accountId;
  }

  @override
  Future<List<ExpenseEntity>> purchasesOf(String tabId) async {
    final query =
        database.select(database.payLaterEntries).join([
            innerJoin(
              database.expenses,
              database.expenses.id.equalsExp(
                database.payLaterEntries.expenseId,
              ),
            ),
          ])
          ..where(database.payLaterEntries.accountId.equals(tabId))
          ..orderBy([
            OrderingTerm.asc(database.expenses.date),
            OrderingTerm.asc(database.expenses.time),
            OrderingTerm.asc(database.expenses.createdAt),
            OrderingTerm.asc(database.expenses.id),
          ]);
    final rows = await query.get();
    return rows
        .map((r) => ExpenseModel.toEntity(r.readTable(database.expenses)))
        .toList();
  }

  JoinedSelectStatement<HasResultSet, dynamic> _inBudget(String budgetId) {
    return database.select(database.payLaterEntries).join([
      innerJoin(
        database.expenses,
        database.expenses.id.equalsExp(database.payLaterEntries.expenseId),
      ),
    ])..where(database.expenses.budgetId.equals(budgetId));
  }

  @override
  Future<int> purchasesInBudget(String budgetId) async {
    return (await _inBudget(budgetId).get()).length;
  }

  @override
  Future<List<String>> tabIdsWithPurchasesInBudget(String budgetId) async {
    final rows = await _inBudget(budgetId).get();
    return rows
        .map((r) => r.read(database.payLaterEntries.accountId)!)
        .toSet()
        .toList();
  }

  @override
  Future<List<String>> tabIdsWithActivity() async {
    final entries = await database.select(database.payLaterEntries).get();
    final payments = await database.select(database.payLaterPayments).get();
    return {
      ...entries.map((e) => e.accountId),
      ...payments.map((p) => p.accountId),
    }.toList();
  }

  @override
  Future<void> createPayment(TabPayment payment) async {
    await database
        .into(database.payLaterPayments)
        .insert(PayLaterModels.paymentToCompanion(payment));
  }

  @override
  Future<void> updatePayment(TabPayment payment) async {
    await (database.update(
      database.payLaterPayments,
    )..where((p) => p.id.equals(payment.id))).write(
      PayLaterModels.paymentToCompanion(
        payment,
      ).copyWith(id: const Value.absent()),
    );
  }

  @override
  Future<void> deletePayment(String id) async {
    // Allocations go with it (ON DELETE CASCADE).
    await (database.delete(
      database.payLaterPayments,
    )..where((p) => p.id.equals(id))).go();
  }

  @override
  Future<TabPayment?> getPayment(String id) async {
    final row = await (database.select(
      database.payLaterPayments,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : PayLaterModels.paymentToEntity(row);
  }

  @override
  Future<List<TabPayment>> paymentsOf(String tabId) async {
    final rows =
        await (database.select(database.payLaterPayments)
              ..where((p) => p.accountId.equals(tabId))
              ..orderBy([
                (p) => OrderingTerm.asc(p.paidDate),
                (p) => OrderingTerm.asc(p.createdAt),
                (p) => OrderingTerm.asc(p.id),
              ]))
            .get();
    return rows.map(PayLaterModels.paymentToEntity).toList();
  }

  @override
  Future<List<PaymentAllocation>> allocationsOf(String tabId) async {
    final query =
        database.select(database.payLaterAllocations).join([
            innerJoin(
              database.payLaterPayments,
              database.payLaterPayments.id.equalsExp(
                database.payLaterAllocations.paymentId,
              ),
            ),
          ])
          ..where(database.payLaterPayments.accountId.equals(tabId))
          ..orderBy([
            OrderingTerm.asc(database.payLaterAllocations.createdAt),
            OrderingTerm.asc(database.payLaterAllocations.id),
          ]);
    final rows = await query.get();
    return rows
        .map(
          (r) => PayLaterModels.allocationToEntity(
            r.readTable(database.payLaterAllocations),
          ),
        )
        .toList();
  }

  @override
  Future<void> applyDiff(AllocationDiff diff) async {
    if (diff.isEmpty) return;
    // Order matters: deletes free a (payment, expense) pair before an insert
    // reuses it (unique key).
    await database.transaction(() async {
      if (diff.deletes.isNotEmpty) {
        await (database.delete(
          database.payLaterAllocations,
        )..where((a) => a.id.isIn(diff.deletes))).go();
      }
      for (final entry in diff.updates.entries) {
        await (database.update(database.payLaterAllocations)
              ..where((a) => a.id.equals(entry.key)))
            .write(PayLaterAllocationsCompanion(amount: Value(entry.value)));
      }
      for (final insert in diff.inserts) {
        await database
            .into(database.payLaterAllocations)
            .insert(PayLaterModels.allocationToCompanion(insert));
      }
    });
  }
}
