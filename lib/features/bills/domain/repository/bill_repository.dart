import '../entities/bill_entity.dart';

/// Contract for bill data access consumed by use cases.
abstract class BillRepository {
  /// Creates a new bill record.
  Future<void> createBill(BillEntity bill);

  /// Updates an existing bill record.
  Future<void> updateBill(BillEntity bill);

  /// Deletes a bill by id.
  Future<void> deleteBill(String id);

  /// Returns a bill by id, or null if not found.
  Future<BillEntity?> getBillById(String id);

  /// Returns all bills.
  Future<List<BillEntity>> getBills();

  /// Creates a payment record for a bill occurrence.
  Future<void> createBillPayment(BillPaymentRecord payment);

  /// Returns payment history for a bill, ordered by paidDate descending.
  Future<List<BillPaymentRecord>> getBillPayments(String billId);

  /// Returns the sum of upcoming (unpaid, non-overdue) bill amounts
  /// within the given number of days from now.
  Future<double> getUpcomingBillsTotal({int withinDays = 30});

  /// Returns the sum of all recurring bill amounts per month.
  Future<double> getMonthlyRecurringBillsTotal();
}
