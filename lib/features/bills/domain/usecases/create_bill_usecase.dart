import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';
import '../validators/bill_validator.dart';

/// Creates a new bill after validating its input.
class CreateBillUseCase {
  final BillRepository repository;

  CreateBillUseCase({required this.repository});

  Future<BillResult<BillEntity>> call(BillEntity bill) async {
    final titleError = BillValidator.validateTitle(bill.title);
    if (titleError != null) {
      return BillError(
        BillFailure(type: BillErrorType.invalidInput, message: titleError),
      );
    }

    final amountError = BillValidator.validateAmountValue(bill.amount);
    if (amountError != null) {
      return BillError(
        BillFailure(type: BillErrorType.invalidInput, message: amountError),
      );
    }

    final dueDateError = BillValidator.validateDueDate(bill.dueDate);
    if (dueDateError != null) {
      return BillError(
        BillFailure(type: BillErrorType.invalidInput, message: dueDateError),
      );
    }

    final noteError = BillValidator.validateNote(bill.note);
    if (noteError != null) {
      return BillError(
        BillFailure(type: BillErrorType.invalidInput, message: noteError),
      );
    }

    final recurrenceError = BillValidator.validateRecurrence(
      isRecurring: bill.isRecurring,
      recurrenceInterval: bill.recurrenceInterval,
    );
    if (recurrenceError != null) {
      return BillError(
        BillFailure(type: BillErrorType.invalidInput, message: recurrenceError),
      );
    }

    try {
      await repository.createBill(bill);
      return BillSuccess(bill);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to save bill: ${e.toString()}',
        ),
      );
    }
  }
}
