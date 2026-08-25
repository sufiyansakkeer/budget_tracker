import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';

/// Loads all bills.
class GetBillsUseCase {
  final BillRepository repository;

  GetBillsUseCase({required this.repository});

  Future<BillResult<List<BillEntity>>> call() async {
    try {
      final bills = await repository.getBills();
      return BillSuccess(bills);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to load bills: ${e.toString()}',
        ),
      );
    }
  }
}
