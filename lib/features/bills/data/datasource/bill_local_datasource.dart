import '../../domain/entities/bill_entity.dart';

/// Local data access for bill CRUD operations.
abstract class BillLocalDataSource {
  Future<void> createBill(BillEntity bill);

  Future<void> updateBill(BillEntity bill);

  Future<void> deleteBill(String id);

  Future<BillEntity?> getBillById(String id);

  Future<List<BillEntity>> getBills();

  Future<void> createBillPayment(BillPaymentRecord payment);

  Future<List<BillPaymentRecord>> getBillPayments(String billId);

  Future<double> getUpcomingBillsTotal({int withinDays = 30});

  Future<double> getMonthlyRecurringBillsTotal();

  /// Runs [action] inside a database transaction. If [action] throws, all
  /// changes within are rolled back.
  Future<T> transaction<T>(Future<T> Function() action);
}
