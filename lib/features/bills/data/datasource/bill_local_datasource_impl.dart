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
  Future<void> deleteBillPayment(String paymentId) async {
    await (database.delete(
      database.billPayments,
    )..where((p) => p.id.equals(paymentId))).go();
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
  Future<List<BillEntity>> getOverdueBills({
    required DateTime today,
    int limit = 3,
  }) async {
    final start = DateTime(today.year, today.month, today.day);
    final query = database.select(database.bills)
      ..where(
        (b) => b.isPaid.equals(false) & b.dueDate.isSmallerThanValue(start),
      )
      ..orderBy([(b) => OrderingTerm.asc(b.dueDate)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(BillModel.toEntity).toList();
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) {
    return database.transaction(action);
  }
}
