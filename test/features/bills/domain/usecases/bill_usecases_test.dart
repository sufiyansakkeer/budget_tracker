import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/entities/bill_failure.dart';
import 'package:monivo/features/bills/domain/repository/bill_repository.dart';
import 'package:monivo/features/bills/domain/usecases/create_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/delete_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/get_bill_by_id_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/get_bills_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_paid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_unpaid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/update_bill_usecase.dart';

class FakeBillRepository implements BillRepository {
  final Map<String, BillEntity> store = {};
  final List<BillPaymentRecord> payments = [];
  bool throwOnWrite = false;

  @override
  Future<void> createBill(BillEntity bill) async {
    if (throwOnWrite) throw Exception('db failure');
    store[bill.id] = bill;
  }

  @override
  Future<void> updateBill(BillEntity bill) async {
    if (throwOnWrite) throw Exception('db failure');
    store[bill.id] = bill;
  }

  @override
  Future<void> deleteBill(String id) async {
    if (throwOnWrite) throw Exception('db failure');
    store.remove(id);
    payments.removeWhere((p) => p.billId == id);
  }

  @override
  Future<BillEntity?> getBillById(String id) async => store[id];

  @override
  Future<List<BillEntity>> getBills() async {
    if (throwOnWrite) throw Exception('db failure');
    return store.values.toList();
  }

  @override
  Future<void> createBillPayment(BillPaymentRecord payment) async {
    payments.add(payment);
  }

  @override
  Future<List<BillPaymentRecord>> getBillPayments(String billId) async =>
      payments.where((p) => p.billId == billId).toList();

  @override
  Future<double> getUpcomingBillsTotal({int withinDays = 30}) async => 0;

  @override
  Future<double> getMonthlyRecurringBillsTotal() async => 0;
}

BillEntity validBill({
  String id = 'bill-1',
  double amount = 1000,
  bool isPaid = false,
  bool isRecurring = false,
  RecurrenceType recurrenceType = RecurrenceType.none,
}) {
  final now = DateTime(2026, 8, 25);
  return BillEntity(
    id: id,
    title: 'Test Bill',
    amount: amount,
    currency: 'INR',
    category: BillCategory.utilities,
    dueDate: DateTime(2026, 9, 1),
    isRecurring: isRecurring,
    recurrenceType: recurrenceType,
    isPaid: isPaid,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeBillRepository repository;

  setUp(() {
    repository = FakeBillRepository();
  });

  group('CreateBillUseCase', () {
    test('creates bill successfully with valid input', () async {
      final useCase = CreateBillUseCase(repository: repository);
      final bill = validBill();

      final result = await useCase(bill);

      expect(result, isA<BillSuccess<BillEntity>>());
      expect(repository.store.length, 1);
    });

    test('returns invalidInput for empty title', () async {
      final useCase = CreateBillUseCase(repository: repository);
      final bill = validBill().copyWith(title: '');

      final result = await useCase(bill);

      expect(result, isA<BillError<BillEntity>>());
      final error = result as BillError<BillEntity>;
      expect(error.failure.type, BillErrorType.invalidInput);
    });

    test('returns invalidInput for zero amount', () async {
      final useCase = CreateBillUseCase(repository: repository);
      final bill = validBill(amount: 0);

      final result = await useCase(bill);

      expect(result, isA<BillError<BillEntity>>());
      final error = result as BillError<BillEntity>;
      expect(error.failure.type, BillErrorType.invalidInput);
    });

    test('returns databaseFailure when repository throws', () async {
      repository.throwOnWrite = true;
      final useCase = CreateBillUseCase(repository: repository);

      final result = await useCase(validBill());

      expect(result, isA<BillError<BillEntity>>());
      final error = result as BillError<BillEntity>;
      expect(error.failure.type, BillErrorType.databaseFailure);
    });
  });

  group('UpdateBillUseCase', () {
    test('updates an existing bill successfully', () async {
      repository.store['bill-1'] = validBill();
      final useCase = UpdateBillUseCase(repository: repository);
      final updated = validBill(amount: 2000);

      final result = await useCase(updated);

      expect(result, isA<BillSuccess<BillEntity>>());
      expect(repository.store['bill-1']!.amount, 2000);
    });

    test('returns notFound when bill does not exist', () async {
      final useCase = UpdateBillUseCase(repository: repository);

      final result = await useCase(validBill());

      expect(result, isA<BillError<BillEntity>>());
      final error = result as BillError<BillEntity>;
      expect(error.failure.type, BillErrorType.notFound);
    });
  });

  group('DeleteBillUseCase', () {
    test('deletes an existing bill successfully', () async {
      repository.store['bill-1'] = validBill();
      final useCase = DeleteBillUseCase(repository: repository);

      final result = await useCase('bill-1');

      expect(result, isA<BillSuccess<void>>());
      expect(repository.store.containsKey('bill-1'), isFalse);
    });

    test('returns invalidInput for empty id', () async {
      final useCase = DeleteBillUseCase(repository: repository);

      final result = await useCase('');

      expect(result, isA<BillError<void>>());
      final error = result as BillError<void>;
      expect(error.failure.type, BillErrorType.invalidInput);
    });

    test('returns notFound when bill does not exist', () async {
      final useCase = DeleteBillUseCase(repository: repository);

      final result = await useCase('missing');

      expect(result, isA<BillError<void>>());
      final error = result as BillError<void>;
      expect(error.failure.type, BillErrorType.notFound);
    });
  });

  group('GetBillByIdUseCase', () {
    test('returns bill when found', () async {
      repository.store['bill-1'] = validBill();
      final useCase = GetBillByIdUseCase(repository: repository);

      final result = await useCase('bill-1');

      expect(result, isA<BillSuccess<BillEntity>>());
      expect((result as BillSuccess<BillEntity>).data.id, 'bill-1');
    });

    test('returns notFound when missing', () async {
      final useCase = GetBillByIdUseCase(repository: repository);

      final result = await useCase('missing');

      expect(result, isA<BillError<BillEntity>>());
      expect(
        (result as BillError<BillEntity>).failure.type,
        BillErrorType.notFound,
      );
    });
  });

  group('GetBillsUseCase', () {
    test('returns all bills', () async {
      repository.store['bill-1'] = validBill(id: 'bill-1');
      repository.store['bill-2'] = validBill(id: 'bill-2');
      final useCase = GetBillsUseCase(repository: repository);

      final result = await useCase();

      expect(result, isA<BillSuccess<List<BillEntity>>>());
      expect((result as BillSuccess<List<BillEntity>>).data.length, 2);
    });

    test('returns databaseFailure when repository throws', () async {
      repository.throwOnWrite = true;
      final useCase = GetBillsUseCase(repository: repository);

      final result = await useCase();

      expect(result, isA<BillError<List<BillEntity>>>());
    });
  });

  group('MarkBillPaidUseCase', () {
    test('marks a one-time bill as paid', () async {
      repository.store['bill-1'] = validBill();
      final useCase = MarkBillPaidUseCase(repository: repository);

      final result = await useCase('bill-1');

      expect(result, isA<BillSuccess<BillEntity>>());
      final updated = (result as BillSuccess<BillEntity>).data;
      expect(updated.isPaid, isTrue);
      expect(updated.paidDate, isNotNull);
      expect(repository.payments.length, 1);
    });

    test('advances a recurring monthly bill to next month', () async {
      repository.store['bill-1'] = validBill(
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
      );
      final useCase = MarkBillPaidUseCase(repository: repository);

      final result = await useCase('bill-1');

      expect(result, isA<BillSuccess<BillEntity>>());
      final updated = (result as BillSuccess<BillEntity>).data;
      expect(updated.isPaid, isFalse); // Still active
      expect(updated.dueDate, DateTime(2026, 10, 1)); // Next month
      expect(repository.payments.length, 1);
    });

    test('returns notFound for missing bill', () async {
      final useCase = MarkBillPaidUseCase(repository: repository);

      final result = await useCase('missing');

      expect(result, isA<BillError<BillEntity>>());
      expect(
        (result as BillError<BillEntity>).failure.type,
        BillErrorType.notFound,
      );
    });
  });

  group('MarkBillUnpaidUseCase', () {
    test('marks a paid bill as unpaid', () async {
      repository.store['bill-1'] = validBill(isPaid: true);
      final useCase = MarkBillUnpaidUseCase(repository: repository);

      final result = await useCase('bill-1');

      expect(result, isA<BillSuccess<BillEntity>>());
      final updated = (result as BillSuccess<BillEntity>).data;
      expect(updated.isPaid, isFalse);
      expect(updated.paidDate, isNull);
    });

    test('returns bill unchanged if already unpaid', () async {
      repository.store['bill-1'] = validBill(isPaid: false);
      final useCase = MarkBillUnpaidUseCase(repository: repository);

      final result = await useCase('bill-1');

      expect(result, isA<BillSuccess<BillEntity>>());
      final updated = (result as BillSuccess<BillEntity>).data;
      expect(updated.isPaid, isFalse);
    });
  });
}
