import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';

/// Loads a single bill by id.
class GetBillByIdUseCase {
  final BillRepository repository;

  GetBillByIdUseCase({required this.repository});

  Future<BillResult<BillEntity>> call(String id) async {
    try {
      final bill = await repository.getBillById(id);
      if (bill == null) {
        return const BillError(
          BillFailure(
            type: BillErrorType.notFound,
            message: 'Bill not found',
          ),
        );
      }
      return BillSuccess(bill);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to load bill: ${e.toString()}',
        ),
      );
    }
  }
}
