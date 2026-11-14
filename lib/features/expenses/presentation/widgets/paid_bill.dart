import 'package:flutter/foundation.dart';

import '../../../../core/di/injection.dart';
import '../../../bills/domain/entities/bill_failure.dart';
import '../../../bills/domain/usecases/get_bill_by_id_usecase.dart';
import '../../domain/entities/expense_entity.dart';

/// The bill an expense paid, for "Paid bill: Rent" on its details and in
/// its move and delete hints.
///
/// Deleting the expense leaves the bill paid; moving it to another budget
/// unlinks it from the bill (it becomes plain spending there).
abstract final class PaidBill {
  /// The title of the bill [expense] paid; null when it paid none, or the
  /// bill is gone or can't be read.
  static Future<String?> titleOf(ExpenseEntity expense) async {
    final id = expense.billId;
    if (id == null) return null;
    try {
      final result = await getIt<GetBillByIdUseCase>()(id);
      return switch (result) {
        BillSuccess(:final data) => data.title,
        _ => null,
      };
    } catch (e) {
      debugPrint('[error] Reading the bill an expense paid: $e');
      return null;
    }
  }

  static String moveHint(String title) =>
      'Paid bill: $title. Moving it unlinks it from the bill.';

  static String deleteHint(String title) =>
      'Paid bill: $title. The bill stays paid.';
}
