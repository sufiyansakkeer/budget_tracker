import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';
import '../validators/bill_validator.dart';

/// Updates an existing bill, checked against the same rules as a new one.
class UpdateBillUseCase {
  final BillRepository repository;

  UpdateBillUseCase({required this.repository});

  Future<BillResult<BillEntity>> call(BillEntity bill) async {
    final invalid = BillValidator.check(bill);
    if (invalid != null) {
      return BillError(
        BillFailure(type: BillErrorType.invalidInput, message: invalid),
      );
    }

    try {
      final existing = await repository.getBillById(bill.id);
      if (existing == null) {
        return const BillError(
          BillFailure(type: BillErrorType.notFound, message: 'Bill not found'),
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
