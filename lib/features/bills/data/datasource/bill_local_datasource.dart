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

  Future<void> deleteBillPayment(String paymentId);

  /// Unpaid bills due on or after [from] (default: today), soonest first.
  ///
  /// Used by the dashboard, which shows only the next few — loading every
  /// bill to sort and take three in Dart wasted the due-date index.
  Future<List<BillEntity>> getUpcomingBills({DateTime? from, int limit = 3});

  /// Unpaid bills due before [today], the longest overdue first.
  ///
  /// Home lists these ahead of the upcoming ones: an overdue bill is the
  /// one most in need of attention, and the safe-to-spend engine still sets
  /// overdue occurrences of linked bills aside.
  Future<List<BillEntity>> getOverdueBills({
    required DateTime today,
    int limit = 3,
  });

  Future<double> getUpcomingBillsTotal({int withinDays = 30});

  Future<double> getMonthlyRecurringBillsTotal();

  /// Runs [action] inside a database transaction. If [action] throws, all
  /// changes within are rolled back.
  Future<T> transaction<T>(Future<T> Function() action);
}
