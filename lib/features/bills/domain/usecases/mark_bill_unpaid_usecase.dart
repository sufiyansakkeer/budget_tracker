import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/domain/repository/expense_repository.dart';
import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';

/// Marks a paid bill as unpaid, restoring its reminder schedule.
///
/// Undoes the payment, in one transaction: the newest payment record is
/// deleted, and so is the expense that settled the bill's set-aside money,
/// so the bill is deducted as upcoming again without its payment also being
/// counted as spent. Deleting the expense recomputes its budget's remaining
/// amount.
///
/// The settling expense is the one with this bill's id that was recorded
/// when the bill was marked paid (`PayBillUseCase` stamps the expense's
/// `createdAt` and the bill's `paidDate` with the same moment). Its date is
/// not used: the user may have edited it, and a calendar day depends on the
/// device's time zone. An expense with this bill's id recorded before that
/// (paying an earlier occurrence while the bill was recurring) is kept.
///
/// Only one-time bills are ever marked paid; a recurring bill advances
/// instead, so it has nothing to undo here.
class MarkBillUnpaidUseCase {
  final BillRepository repository;
  final ExpenseRepository expenseRepository;

  MarkBillUnpaidUseCase({
    required this.repository,
    required this.expenseRepository,
  });

  /// Returns the updated bill.
  Future<BillResult<BillEntity>> call(String billId) async {
    try {
      final bill = await repository.getBillById(billId);
      if (bill == null) {
        return const BillError(
          BillFailure(type: BillErrorType.notFound, message: 'Bill not found'),
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

      await repository.transaction(() async {
        // Newest first.
        final payments = await repository.getBillPayments(bill.id);
        if (payments.isNotEmpty) {
          await repository.deleteBillPayment(payments.first.id);
        }
        for (final expense in await _settlingExpenses(bill)) {
          await expenseRepository.deleteExpense(expense.id);
        }
        await repository.updateBill(updatedBill);
      });
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

  /// The expenses [call] would delete for this bill, so a confirmation can
  /// name them. Empty when the bill is unpaid or was paid without recording
  /// a set-aside payment.
  Future<BillResult<List<ExpenseEntity>>> expensesToRemove(
    String billId,
  ) async {
    try {
      final bill = await repository.getBillById(billId);
      if (bill == null) {
        return const BillError(
          BillFailure(type: BillErrorType.notFound, message: 'Bill not found'),
        );
      }
      if (!bill.isPaid) return const BillSuccess([]);
      return BillSuccess(await _settlingExpenses(bill));
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to load the bill payment: ${e.toString()}',
        ),
      );
    }
  }

  /// Expenses with this bill's id recorded at or after the moment the bill
  /// was marked paid (to the second, the precision the database keeps), in
  /// whichever budget and on whichever date they now are.
  Future<List<ExpenseEntity>> _settlingExpenses(BillEntity bill) async {
    final paidDate = bill.paidDate;
    if (paidDate == null) return const [];
    final paidSecond = _toSecond(paidDate);
    final forBill = await expenseRepository.getExpensesForBill(bill.id);
    return forBill.where((e) => _toSecond(e.createdAt) >= paidSecond).toList();
  }

  static int _toSecond(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
}
