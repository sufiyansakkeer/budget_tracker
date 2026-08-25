import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';
import '../validators/bill_validator.dart';

/// Updates an existing bill after validating its input.
class UpdateBillUseCase {
  final BillRepository repository;

  UpdateBillUseCase({required this.repository});

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

    try {
      final existing = await repository.getBillById(bill.id);
      if (existing == null) {
        return const BillError(
          BillFailure(
            type: BillErrorType.notFound,
            message: 'Bill not found',
          ),
        );
      }
      await repository.updateBill(bill);
      return BillSuccess(bill);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to update bill: ${e.toString()}',
        ),
      );
    }
  }
}
