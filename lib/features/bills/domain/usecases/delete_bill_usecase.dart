import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';

/// Deletes a bill by id.
class DeleteBillUseCase {
  final BillRepository repository;

  DeleteBillUseCase({required this.repository});

  Future<BillResult<void>> call(String id) async {
    if (id.isEmpty) {
      return const BillError(
        BillFailure(
          type: BillErrorType.invalidInput,
          message: 'Bill id cannot be empty',
        ),
      );
    }

    try {
      final existing = await repository.getBillById(id);
      if (existing == null) {
        return const BillError(
          BillFailure(
            type: BillErrorType.notFound,
            message: 'Bill not found',
          ),
        );
      }
      await repository.deleteBill(id);
      return const BillSuccess(null);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to delete bill: ${e.toString()}',
        ),
      );
    }
  }
}
