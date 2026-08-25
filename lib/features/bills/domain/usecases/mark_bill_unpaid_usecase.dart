import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';

/// Marks a paid bill as unpaid, restoring its reminder schedule.
class MarkBillUnpaidUseCase {
  final BillRepository repository;

  MarkBillUnpaidUseCase({required this.repository});

  /// Returns the updated bill.
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

      if (!bill.isPaid) {
        return BillSuccess(bill); // Already unpaid, nothing to do.
      }

      final updatedBill = bill.copyWith(
        isPaid: false,
        clearPaidDate: true,
        updatedAt: DateTime.now(),
      );
      await repository.updateBill(updatedBill);
      return BillSuccess(updatedBill);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to mark bill as unpaid: ${e.toString()}',
        ),
      );
    }
  }
}
