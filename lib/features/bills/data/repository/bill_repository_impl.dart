import '../../domain/entities/bill_entity.dart';
import '../../domain/repository/bill_repository.dart';
import '../datasource/bill_local_datasource.dart';

class BillRepositoryImpl implements BillRepository {
  final BillLocalDataSource localDataSource;

  BillRepositoryImpl({required this.localDataSource});

  @override
  Future<void> createBill(BillEntity bill) async {
    await localDataSource.createBill(bill);
  }

  @override
  Future<void> updateBill(BillEntity bill) async {
    await localDataSource.updateBill(bill);
  }

  @override
  Future<void> deleteBill(String id) async {
    await localDataSource.deleteBill(id);
  }

  @override
  Future<BillEntity?> getBillById(String id) async {
    return localDataSource.getBillById(id);
  }

  @override
  Future<List<BillEntity>> getBills() async {
    return localDataSource.getBills();
  }

  @override
  Future<void> createBillPayment(BillPaymentRecord payment) async {
    await localDataSource.createBillPayment(payment);
  }

  @override
  Future<List<BillPaymentRecord>> getBillPayments(String billId) async {
    return localDataSource.getBillPayments(billId);
  }

  @override
  Future<double> getUpcomingBillsTotal({int withinDays = 30}) async {
    return localDataSource.getUpcomingBillsTotal(withinDays: withinDays);
  }

  @override
  Future<double> getMonthlyRecurringBillsTotal() async {
    return localDataSource.getMonthlyRecurringBillsTotal();
  }
}
