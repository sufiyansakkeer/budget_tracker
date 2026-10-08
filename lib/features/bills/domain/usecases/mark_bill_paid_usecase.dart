import 'package:uuid/uuid.dart';

import '../entities/bill_entity.dart';
import '../entities/bill_enums.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';

/// Marks a bill as paid.
///
/// For recurring bills, advances to the next occurrence instead of permanently
/// marking as paid. Creates a payment history record.
///
/// The payment record creation and bill update run atomically — if either
/// fails, no partial state is left in the database.
class MarkBillPaidUseCase {
  final BillRepository repository;

  MarkBillPaidUseCase({required this.repository});

  /// The bill after its current occurrence is paid at [now]: a recurring
  /// bill moves to its next due date and stays unpaid; a one-time bill is
  /// marked paid. Shared with `PayBillUseCase` so both pay the same way.
  static BillEntity settle(BillEntity bill, DateTime now) {
    if (bill.isRecurring && bill.recurrenceType != RecurrenceType.none) {
      // For recurring bills: advance the due date, keep active.
      return bill.copyWith(
        dueDate: bill.nextDueDate,
        isPaid: false,
        clearPaidDate: true,
        updatedAt: now,
      );
    }
    // For one-time bills: mark as paid.
    return bill.copyWith(isPaid: true, paidDate: now, updatedAt: now);
  }

  /// Returns the updated bill (next occurrence for recurring, or marked paid).
  Future<BillResult<BillEntity>> call(String billId) async {
    try {
      final bill = await repository.getBillById(billId);
      if (bill == null) {
        return const BillError(
          BillFailure(type: BillErrorType.notFound, message: 'Bill not found'),
        );
      }

      final now = DateTime.now();

      // Create a payment record.
      final payment = BillPaymentRecord(
        id: const Uuid().v4(),
        billId: bill.id,
        amount: bill.amount,
        currency: bill.currency,
        paidDate: now,
        createdAt: now,
      );

      final updatedBill = settle(bill, now);

      // Atomic: payment record + bill update
      await repository.transaction(() async {
        await repository.createBillPayment(payment);
        await repository.updateBill(updatedBill);
      });

      return BillSuccess(updatedBill);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to mark bill as paid: ${e.toString()}',
        ),
      );
    }
  }
}
