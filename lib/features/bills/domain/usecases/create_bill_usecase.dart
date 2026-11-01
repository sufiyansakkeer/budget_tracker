import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';
import '../validators/bill_validator.dart';

/// Creates a new bill after validating its input.
class CreateBillUseCase {
  final BillRepository repository;

  CreateBillUseCase({required this.repository});

  Future<BillResult<BillEntity>> call(BillEntity bill) async {
    final invalid = BillValidator.check(bill);
    if (invalid != null) {
      return BillError(
        BillFailure(type: BillErrorType.invalidInput, message: invalid),
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
