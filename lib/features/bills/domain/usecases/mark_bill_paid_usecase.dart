import 'package:uuid/uuid.dart';

import '../entities/bill_entity.dart';
import '../entities/bill_enums.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';

/// Marks a bill as paid.
///
/// For recurring bills, advances to the next occurrence instead of permanently
/// marking as paid. Creates a payment history record.
class MarkBillPaidUseCase {
  final BillRepository repository;

  MarkBillPaidUseCase({required this.repository});

  /// Returns the updated bill (next occurrence for recurring, or marked paid).
  Future<BillResult<BillEntity>> call(String billId) async {
    try {
      final bill = await repository.getBillById(billId);
      if (bill == null) {
        return const BillError(
          BillFailure(
            type: BillErrorType.notFound,
            message: 'Bill not found',
          ),
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
      await repository.createBillPayment(payment);

      if (bill.isRecurring &&
          bill.recurrenceType != RecurrenceType.none) {
        // For recurring bills: advance the due date, keep active.
        final updatedBill = bill.copyWith(
          dueDate: bill.nextDueDate,
          isPaid: false,
          clearPaidDate: true,
          updatedAt: now,
        );
        await repository.updateBill(updatedBill);
        return BillSuccess(updatedBill);
      } else {
        // For one-time bills: mark as paid.
        final updatedBill = bill.copyWith(
          isPaid: true,
          paidDate: now,
          updatedAt: now,
        );
        await repository.updateBill(updatedBill);
        return BillSuccess(updatedBill);
      }
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
