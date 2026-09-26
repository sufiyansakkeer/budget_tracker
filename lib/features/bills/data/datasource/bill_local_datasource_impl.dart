import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/bill_entity.dart';
import '../models/bill_model.dart';
import 'bill_local_datasource.dart';

class BillLocalDataSourceImpl implements BillLocalDataSource {
  final AppDatabase database;

  BillLocalDataSourceImpl({required this.database});

  @override
  Future<void> createBill(BillEntity bill) async {
    await database
        .into(database.bills)
        .insert(BillModel.toInsertCompanion(bill));
  }

  @override
  Future<void> updateBill(BillEntity bill) async {
    await (database.update(database.bills)..where((b) => b.id.equals(bill.id)))
        .write(BillModel.toUpdateCompanion(bill));
  }

  @override
  Future<void> deleteBill(String id) async {
    // Delete associated payment records and bill atomically.
    await database.transaction(() async {
      await (database.delete(
        database.billPayments,
      )..where((p) => p.billId.equals(id))).go();
      await (database.delete(
        database.bills,
      )..where((b) => b.id.equals(id))).go();
    });
  }

  @override
  Future<BillEntity?> getBillById(String id) async {
    final query = database.select(database.bills)
      ..where((b) => b.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return BillModel.toEntity(row);
  }

  @override
  Future<List<BillEntity>> getBills() async {
    final query = database.select(database.bills)
      ..orderBy([(b) => OrderingTerm.asc(b.dueDate)]);
    final rows = await query.get();
    return rows.map(BillModel.toEntity).toList();
  }

  @override
  Future<void> createBillPayment(BillPaymentRecord payment) async {
    await database
        .into(database.billPayments)
        .insert(BillModel.paymentToCompanion(payment));
  }

  @override
  Future<List<BillPaymentRecord>> getBillPayments(String billId) async {
    final query = database.select(database.billPayments)
      ..where((p) => p.billId.equals(billId))
      ..orderBy([(p) => OrderingTerm.desc(p.paidDate)]);
    final rows = await query.get();
    return rows.map(BillModel.paymentToEntity).toList();
  }

  @override
  Future<List<BillEntity>> getUpcomingBills({
    DateTime? from,
    int limit = 3,
  }) async {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final query = database.select(database.bills)
      ..where(
        (b) => b.isPaid.equals(false) & b.dueDate.isBiggerOrEqualValue(today),
      )
      ..orderBy([(b) => OrderingTerm.asc(b.dueDate)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(BillModel.toEntity).toList();
  }

  @override
  Future<double> getUpcomingBillsTotal({int withinDays = 30}) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final cutoff = todayDate.add(Duration(days: withinDays));

    final sum = database.bills.amount.sum();
    final query = database.selectOnly(database.bills)
      ..addColumns([sum])
      ..where(
        database.bills.isPaid.equals(false) &
            database.bills.dueDate.isBiggerOrEqualValue(todayDate) &
            database.bills.dueDate.isSmallerOrEqualValue(cutoff),
      );
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  @override
  Future<double> getMonthlyRecurringBillsTotal() async {
    final query = database.select(database.bills)
      ..where((b) => b.isRecurring.equals(true) & b.isPaid.equals(false));
    final rows = await query.get();
    double total = 0;
    for (final row in rows) {
      // "Every N weeks/months/years": a bill due every 2 months costs half
      // of its amount per month.
      final interval = row.recurrenceInterval < 1 ? 1 : row.recurrenceInterval;
      switch (row.recurrenceType) {
        case 'weekly':
          total += row.amount * (52 / 12) / interval;
          break;
        case 'monthly':
          total += row.amount / interval;
          break;
        case 'yearly':
          total += row.amount / 12 / interval;
          break;
        default:
          break;
      }
    }
    return total;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) {
    return database.transaction(action);
  }
}
