import '../../../expenses/domain/entities/expense_failure.dart';
import '../../../expenses/domain/usecases/delete_expense_usecase.dart';
import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../entities/bill_snapshot.dart';
import '../repository/bill_repository.dart';

/// Undo for a bill change: puts the bill and its payment history back as a
/// [BillSnapshot] captured before the change, and deletes the expense the
/// change recorded.
///
/// One transaction, so an undo is all or nothing:
/// * the recorded expense is deleted through [DeleteExpenseUseCase], the
///   same path as deleting it from Expenses, so its budget's remaining
///   amount is recomputed. One already deleted is skipped;
/// * the bill row is written back as it was (re-inserted with its own id
///   when the change deleted it);
/// * payment rows the change added are deleted, and rows it removed are
///   re-inserted.
///
/// Expenses the change didn't record are untouched: deleting a bill keeps
/// the expenses that paid it, so they still carry its id when it returns.
///
/// Reminders are the caller's: it cancels the bill's reminder and
/// schedules one for the restored bill, as for any other bill change.
class RestoreBillSnapshotUseCase {
  final BillRepository repository;
  final DeleteExpenseUseCase deleteExpense;

  RestoreBillSnapshotUseCase({
    required this.repository,
    required this.deleteExpense,
  });

  /// The bill [billId] and its payments as stored now, to restore later.
  Future<BillResult<BillSnapshot>> capture(String billId) async {
    try {
      final bill = await repository.getBillById(billId);
      if (bill == null) {
        return const BillError(
          BillFailure(type: BillErrorType.notFound, message: 'Bill not found'),
        );
      }
      final payments = await repository.getBillPayments(billId);
      return BillSuccess(BillSnapshot(bill: bill, payments: payments));
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to read the bill: ${e.toString()}',
        ),
      );
    }
  }

  /// Restores [before] and deletes [recordedExpenseId] (the expense the
  /// change being undone recorded, if any). Returns the restored bill.
  Future<BillResult<BillEntity>> call(
    BillSnapshot before, {
    String? recordedExpenseId,
  }) async {
    final bill = before.bill;
    try {
      await repository.transaction(() async {
        if (recordedExpenseId != null) {
          final deleted = await deleteExpense(recordedExpenseId);
          if (deleted case ExpenseError(
            :final failure,
          ) when failure.type != ExpenseErrorType.notFound) {
            // Rolls the whole undo back.
            throw StateError(failure.message);
          }
        }

        if (await repository.getBillById(bill.id) == null) {
          await repository.createBill(bill);
        } else {
          await repository.updateBill(bill);
        }

        final kept = {for (final p in before.payments) p.id};
        final current = await repository.getBillPayments(bill.id);
        for (final payment in current) {
          if (!kept.contains(payment.id)) {
            await repository.deleteBillPayment(payment.id);
          }
        }
        final present = {for (final p in current) p.id};
        for (final payment in before.payments) {
          if (!present.contains(payment.id)) {
            await repository.createBillPayment(payment);
          }
        }
      });
      return BillSuccess(bill);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to undo the bill change: ${e.toString()}',
        ),
      );
    }
  }
}
