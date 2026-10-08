import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/repository/bill_repository.dart';
import 'package:monivo/features/bills/domain/usecases/create_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/delete_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/get_bill_by_id_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/get_bills_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_paid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_unpaid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/schedule_bill_reminder_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/pay_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/update_bill_usecase.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_event.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_state.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/bills/domain/entities/bill_failure.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';

import '../../../../helpers/bill_payment_fakes.dart';

class FakeBillRepository implements BillRepository {
  final Map<String, BillEntity> store = {};
  final List<BillPaymentRecord> payments = [];

  @override
  Future<void> createBill(BillEntity bill) async => store[bill.id] = bill;

  @override
  Future<void> updateBill(BillEntity bill) async => store[bill.id] = bill;

  @override
  Future<void> deleteBill(String id) async => store.remove(id);

  @override
  Future<BillEntity?> getBillById(String id) async => store[id];

  @override
  Future<List<BillEntity>> getBills() async => store.values.toList();

  @override
  Future<void> createBillPayment(BillPaymentRecord payment) async =>
      payments.add(payment);

  @override
  Future<List<BillPaymentRecord>> getBillPayments(String billId) async =>
      payments.where((p) => p.billId == billId).toList();

  @override
  Future<void> deleteBillPayment(String paymentId) async =>
      payments.removeWhere((p) => p.id == paymentId);

  @override
  Future<List<BillEntity>> getUpcomingBills({
    DateTime? from,
    int limit = 3,
  }) async {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming =
        (await getBills())
            .where((b) => !b.isPaid && !b.dueDate.isBefore(today))
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming.take(limit).toList();
  }

  @override
  Future<double> getUpcomingBillsTotal({int withinDays = 30}) async => 0;

  @override
  Future<double> getMonthlyRecurringBillsTotal() async => 0;

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}

class FakeBillReminderService extends BillReminderService {
  final List<String> scheduledBillIds = [];
  final List<String> cancelledBillIds = [];

  FakeBillReminderService() : super(repository: FakeBillRepository());

  @override
  Future<void> scheduleReminder(BillEntity bill) async =>
      scheduledBillIds.add(bill.id);

  @override
  Future<void> cancelReminder(BillEntity bill) async =>
      cancelledBillIds.add(bill.id);

  @override
  Future<void> rescheduleAll() async {}

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<void> initialize() async {}
}

BillEntity validBill({String id = 'bill-1', bool isPaid = false}) {
  final now = DateTime.now();
  return BillEntity(
    id: id,
    title: 'Test Bill',
    amount: 1000,
    currency: 'INR',
    category: BillCategory.utilities,
    dueDate: DateTime.now().add(const Duration(days: 7)),
    isPaid: isPaid,
    createdAt: now,
    updatedAt: now,
  );
}

BillBloc buildBloc(
  FakeBillRepository repository, {
  PayBillUseCase? payBill,
  FakeBillReminderService? reminders,
}) {
  final reminderService = reminders ?? FakeBillReminderService();
  return BillBloc(
    createBillUseCase: CreateBillUseCase(repository: repository),
    updateBillUseCase: UpdateBillUseCase(repository: repository),
    deleteBillUseCase: DeleteBillUseCase(repository: repository),
    getBillsUseCase: GetBillsUseCase(repository: repository),
    getBillByIdUseCase: GetBillByIdUseCase(repository: repository),
    markBillPaidUseCase: MarkBillPaidUseCase(repository: repository),
    markBillUnpaidUseCase: MarkBillUnpaidUseCase(
      repository: repository,
      expenseRepository: InMemoryExpenseRepository(),
    ),
    payBillUseCase: payBill ?? FakePayBillUseCase(_unusedPayment),
    reminderService: reminderService,
  );
}

const _unusedPayment = BillError<BillPaymentOutcome>(
  BillFailure(type: BillErrorType.invalidInput, message: 'not used'),
);

void main() {
  late FakeBillRepository repository;

  setUp(() {
    repository = FakeBillRepository();
  });

  test('initial state is BillState initial', () {
    final bloc = buildBloc(repository);
    expect(bloc.state.status, BillBlocStatus.initial);
    expect(bloc.state.allBills, isEmpty);
    bloc.close();
  });

  test('loads all bills', () async {
    await repository.createBill(validBill(id: 'bill-1'));
    await repository.createBill(validBill(id: 'bill-2'));
    final bloc = buildBloc(repository);

    bloc.add(const BillLoadAll());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.allBills.length, 2);
    expect(bloc.state.status, BillBlocStatus.loaded);
    await bloc.close();
  });

  test('loads bill by id', () async {
    await repository.createBill(validBill(id: 'bill-1'));
    final bloc = buildBloc(repository);

    bloc.add(const BillLoadById('bill-1'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.selectedBill?.id, 'bill-1');
    expect(bloc.state.status, BillBlocStatus.loaded);
    await bloc.close();
  });

  test('creates a bill and sets success state', () async {
    final bloc = buildBloc(repository);
    final states = <BillState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(BillCreate(validBill()));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repository.store.containsKey('bill-1'), isTrue);
    // The stream emits success, then loaded (from refresh bus).
    expect(states.any((s) => s.status == BillBlocStatus.success), isTrue);
    await sub.cancel();
    await bloc.close();
  });

  test('updates a bill and sets success state', () async {
    await repository.createBill(validBill());
    final bloc = buildBloc(repository);
    final states = <BillState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(BillUpdate(validBill()));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(states.any((s) => s.status == BillBlocStatus.success), isTrue);
    expect(states.any((s) => s.message == 'Bill updated successfully'), isTrue);
    await sub.cancel();
    await bloc.close();
  });

  test('deletes a bill and sets success state', () async {
    await repository.createBill(validBill());
    final bloc = buildBloc(repository);
    final states = <BillState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const BillDelete('bill-1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repository.store.containsKey('bill-1'), isFalse);
    expect(states.any((s) => s.status == BillBlocStatus.success), isTrue);
    await sub.cancel();
    await bloc.close();
  });

  test('marks bill as paid', () async {
    await repository.createBill(validBill());
    final bloc = buildBloc(repository);
    final states = <BillState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const BillMarkPaid('bill-1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repository.payments.length, 1);
    expect(states.any((s) => s.status == BillBlocStatus.success), isTrue);
    await sub.cancel();
    await bloc.close();
  });

  test('marks bill as unpaid', () async {
    await repository.createBill(validBill(isPaid: true));
    final bloc = buildBloc(repository);
    final states = <BillState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const BillMarkUnpaid('bill-1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(states.any((s) => s.status == BillBlocStatus.success), isTrue);
    final updated = await repository.getBillById('bill-1');
    expect(updated!.isPaid, isFalse);
    await sub.cancel();
    await bloc.close();
  });

  group('BillPayWithExpense', () {
    final paidAt = DateTime(2026, 8, 10, 9, 30);
    final budget = BudgetEntity(
      id: 'budget-1',
      name: 'August',
      monthlyAmount: 30000,
      remainingAmount: 30000,
      currency: 'INR',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

    BillEntity recurringBill() => BillEntity(
      id: 'bill-1',
      title: 'Rent',
      amount: 1000,
      currency: 'INR',
      category: BillCategory.rent,
      dueDate: DateTime(2026, 8, 12),
      isRecurring: true,
      recurrenceType: RecurrenceType.monthly,
      reminderEnabled: true,
      budgetId: 'budget-1',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

    BillPaymentOutcome outcome(BillEntity paid) => BillPaymentOutcome(
      bill: paid,
      expense: ExpenseEntity(
        id: 'expense-1',
        budgetId: budget.id,
        amount: paid.amount,
        categoryId: 'bills',
        note: 'Bill: ${paid.title}',
        date: DateTime(2026, 8, 10),
        time: paidAt,
        createdAt: paidAt,
        updatedAt: paidAt,
        billId: paid.id,
      ),
      budget: budget,
    );

    test('pays through the use case, moves the reminder to the next '
        'occurrence and refreshes bills and expenses', () async {
      final bill = recurringBill();
      await repository.createBill(bill);
      final advanced = bill.copyWith(dueDate: DateTime(2026, 9, 12));
      final payBill = FakePayBillUseCase(BillSuccess(outcome(advanced)));
      final reminders = FakeBillReminderService();
      final bloc = buildBloc(
        repository,
        payBill: payBill,
        reminders: reminders,
      );
      var billChanges = 0;
      var expenseChanges = 0;
      final billSub = RefreshBuses.bills.changes.listen((_) => billChanges++);
      final expenseSub = RefreshBuses.expenses.changes.listen(
        (_) => expenseChanges++,
      );

      bloc.add(const BillPayWithExpense('bill-1'));
      final done = await bloc.stream.firstWhere(
        (s) => s.status == BillBlocStatus.success,
      );

      expect(payBill.paidBillIds, ['bill-1']);
      expect(done.message, 'Marked paid. Expense added to August.');
      expect(reminders.cancelledBillIds, ['bill-1']);
      expect(reminders.scheduledBillIds, ['bill-1']);
      expect(billChanges, 1);
      expect(expenseChanges, 1);
      await billSub.cancel();
      await expenseSub.cancel();
      await bloc.close();
    });

    test('a refused payment shows why and keeps the reminder', () async {
      await repository.createBill(recurringBill());
      final payBill = FakePayBillUseCase(
        const BillError(
          BillFailure(
            type: BillErrorType.invalidInput,
            message: 'No running budget in INR to record this payment',
          ),
        ),
      );
      final reminders = FakeBillReminderService();
      final bloc = buildBloc(
        repository,
        payBill: payBill,
        reminders: reminders,
      );

      bloc.add(const BillPayWithExpense('bill-1'));
      final failed = await bloc.stream.firstWhere(
        (s) => s.status == BillBlocStatus.error,
      );

      expect(failed.message, 'No running budget in INR to record this payment');
      expect(reminders.cancelledBillIds, isEmpty);
      expect(reminders.scheduledBillIds, isEmpty);
      await bloc.close();
    });
  });

  test('filter changes', () async {
    final bloc = buildBloc(repository);

    bloc.add(const BillFilterChanged(BillFilter.overdue));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.filter, BillFilter.overdue);
    await bloc.close();
  });

  test('search changes', () async {
    final bloc = buildBloc(repository);

    bloc.add(const BillSearchChanged('electric'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.searchQuery, 'electric');
    await bloc.close();
  });

  test('clear message resets to initial', () async {
    await repository.createBill(validBill());
    final bloc = buildBloc(repository);
    final states = <BillState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(BillCreate(validBill()));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(states.any((s) => s.status == BillBlocStatus.success), isTrue);

    bloc.add(const BillClearMessage());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, BillBlocStatus.initial);
    expect(bloc.state.message, isNull);
    await sub.cancel();
    await bloc.close();
  });

  group('BillState filtering', () {
    test('filteredBills filters by overdue', () async {
      final now = DateTime.now();
      final overdue = BillEntity(
        id: 'overdue',
        title: 'Overdue Bill',
        amount: 500,
        currency: 'INR',
        category: BillCategory.electricity,
        dueDate: DateTime.now().subtract(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );
      final upcoming = BillEntity(
        id: 'upcoming',
        title: 'Upcoming Bill',
        amount: 1000,
        currency: 'INR',
        category: BillCategory.rent,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );

      final state = BillState(
        allBills: [overdue, upcoming],
        filter: BillFilter.overdue,
      );

      expect(state.filteredBills.length, 1);
      expect(state.filteredBills.first.id, 'overdue');
    });

    test('filteredBills filters by paid', () async {
      final now = DateTime.now();
      final paid = BillEntity(
        id: 'paid',
        title: 'Paid Bill',
        amount: 500,
        currency: 'INR',
        category: BillCategory.phone,
        dueDate: DateTime.now(),
        isPaid: true,
        paidDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final unpaid = BillEntity(
        id: 'unpaid',
        title: 'Unpaid Bill',
        amount: 1000,
        currency: 'INR',
        category: BillCategory.rent,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );

      final state = BillState(
        allBills: [paid, unpaid],
        filter: BillFilter.paid,
      );

      expect(state.filteredBills.length, 1);
      expect(state.filteredBills.first.id, 'paid');
    });

    test('filteredBills filters by recurring', () async {
      final now = DateTime.now();
      final recurring = BillEntity(
        id: 'recurring',
        title: 'Netflix',
        amount: 649,
        currency: 'INR',
        category: BillCategory.subscription,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
        createdAt: now,
        updatedAt: now,
      );
      final onetime = BillEntity(
        id: 'onetime',
        title: 'One-time',
        amount: 1000,
        currency: 'INR',
        category: BillCategory.rent,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );

      final state = BillState(
        allBills: [recurring, onetime],
        filter: BillFilter.recurring,
      );

      expect(state.filteredBills.length, 1);
      expect(state.filteredBills.first.id, 'recurring');
    });

    test('search filters by title', () async {
      final now = DateTime.now();
      final electricity = BillEntity(
        id: 'elec',
        title: 'Electricity',
        amount: 1250,
        currency: 'INR',
        category: BillCategory.electricity,
        dueDate: DateTime.now().add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );
      final rent = BillEntity(
        id: 'rent',
        title: 'Rent',
        amount: 25000,
        currency: 'INR',
        category: BillCategory.rent,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );

      final state = BillState(
        allBills: [electricity, rent],
        searchQuery: 'electric',
      );

      expect(state.filteredBills.length, 1);
      expect(state.filteredBills.first.id, 'elec');
    });

    test('search works with category name', () async {
      final now = DateTime.now();
      final internet = BillEntity(
        id: 'net',
        title: 'Airtel Fibre',
        amount: 799,
        currency: 'INR',
        category: BillCategory.internet,
        dueDate: DateTime.now().subtract(const Duration(days: 3)),
        createdAt: now,
        updatedAt: now,
      );

      final state = BillState(allBills: [internet], searchQuery: 'internet');

      expect(state.filteredBills.length, 1);
      expect(state.filteredBills.first.id, 'net');
    });

    test('sorting puts overdue before due today before upcoming', () async {
      final now = DateTime.now();
      final upcoming = BillEntity(
        id: 'upcoming',
        title: 'Upcoming',
        amount: 1000,
        currency: 'INR',
        category: BillCategory.rent,
        dueDate: DateTime.now().add(const Duration(days: 14)),
        createdAt: now,
        updatedAt: now,
      );
      final overdue = BillEntity(
        id: 'overdue',
        title: 'Overdue',
        amount: 500,
        currency: 'INR',
        category: BillCategory.electricity,
        dueDate: DateTime.now().subtract(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );
      final dueToday = BillEntity(
        id: 'today',
        title: 'Today',
        amount: 799,
        currency: 'INR',
        category: BillCategory.internet,
        dueDate: DateTime.now(),
        createdAt: now,
        updatedAt: now,
      );

      final state = BillState(allBills: [upcoming, overdue, dueToday]);

      expect(state.filteredBills[0].id, 'overdue');
      expect(state.filteredBills[1].id, 'today');
      expect(state.filteredBills[2].id, 'upcoming');
    });

    test('paid bills go to the bottom', () async {
      final now = DateTime.now();
      final paid = BillEntity(
        id: 'paid',
        title: 'Paid',
        amount: 500,
        currency: 'INR',
        category: BillCategory.phone,
        dueDate: DateTime.now(),
        isPaid: true,
        paidDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final overdue = BillEntity(
        id: 'overdue',
        title: 'Overdue',
        amount: 1000,
        currency: 'INR',
        category: BillCategory.electricity,
        dueDate: DateTime.now().subtract(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );

      final state = BillState(allBills: [paid, overdue]);

      expect(state.filteredBills[0].id, 'overdue');
      expect(state.filteredBills[1].id, 'paid');
    });
  });

  group('BillState computed properties', () {
    test('upcomingTotal sums unpaid upcoming and due today bills', () {
      final now = DateTime.now();
      final state = BillState(
        allBills: [
          BillEntity(
            id: '1',
            title: 'Due Today',
            amount: 1000,
            currency: 'INR',
            category: BillCategory.electricity,
            dueDate: DateTime.now(),
            createdAt: now,
            updatedAt: now,
          ),
          BillEntity(
            id: '2',
            title: 'Upcoming',
            amount: 2000,
            currency: 'INR',
            category: BillCategory.rent,
            dueDate: DateTime.now().add(const Duration(days: 7)),
            createdAt: now,
            updatedAt: now,
          ),
          BillEntity(
            id: '3',
            title: 'Paid',
            amount: 500,
            currency: 'INR',
            category: BillCategory.phone,
            dueDate: DateTime.now(),
            isPaid: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(state.upcomingTotal, 3000); // 1000 + 2000, not 500
    });

    test('overdueTotal sums overdue bills only', () {
      final now = DateTime.now();
      final state = BillState(
        allBills: [
          BillEntity(
            id: '1',
            title: 'Overdue',
            amount: 799,
            currency: 'INR',
            category: BillCategory.internet,
            dueDate: DateTime.now().subtract(const Duration(days: 7)),
            createdAt: now,
            updatedAt: now,
          ),
          BillEntity(
            id: '2',
            title: 'Upcoming',
            amount: 2000,
            currency: 'INR',
            category: BillCategory.rent,
            dueDate: DateTime.now().add(const Duration(days: 7)),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(state.overdueTotal, 799);
    });

    test('upcomingTotal excludes overdue and paid bills', () {
      final now = DateTime.now();
      final state = BillState(
        allBills: [
          BillEntity(
            id: '1',
            title: 'Upcoming unpaid',
            amount: 2000,
            currency: 'INR',
            category: BillCategory.rent,
            dueDate: DateTime.now().add(const Duration(days: 7)),
            createdAt: now,
            updatedAt: now,
          ),
          BillEntity(
            id: '2',
            title: 'Due today unpaid',
            amount: 1000,
            currency: 'INR',
            category: BillCategory.electricity,
            dueDate: DateTime.now(),
            createdAt: now,
            updatedAt: now,
          ),
          BillEntity(
            id: '3',
            title: 'Overdue unpaid',
            amount: 500,
            currency: 'INR',
            category: BillCategory.phone,
            dueDate: DateTime.now().subtract(const Duration(days: 3)),
            createdAt: now,
            updatedAt: now,
          ),
          BillEntity(
            id: '4',
            title: 'Paid upcoming',
            amount: 700,
            currency: 'INR',
            category: BillCategory.subscription,
            dueDate: DateTime.now().add(const Duration(days: 10)),
            isPaid: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(state.upcomingTotal, 3000); // 2000 + 1000
    });
  });
}
