import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/expenses/domain/entities/activity_extra.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/usecases/get_activity_extras_usecase.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';

import '../../../../helpers/pay_later_memory_repository.dart';

void main() {
  final created = DateTime(2026, 11, 1);

  BudgetEntity budget(String id, DateTime start, DateTime end) => BudgetEntity(
    id: id,
    name: id == 'b1' ? 'November' : 'Trip',
    monthlyAmount: 30000,
    remainingAmount: 30000,
    currency: 'INR',
    startDate: start,
    endDate: end,
    createdAt: created,
    updatedAt: created,
  );

  ExpenseEntity expense(String id, String budgetId, DateTime date) =>
      ExpenseEntity(
        id: id,
        budgetId: budgetId,
        amount: 120,
        categoryId: 'food',
        date: date,
        time: date,
        createdAt: date,
        updatedAt: date,
      );

  PayLaterTab tab(String id, String name) => PayLaterTab(
    id: id,
    name: name,
    category: PayLaterTabCategory.foodDining,
    currency: 'INR',
    rhythm: const OnDemand(),
    createdAt: created,
    updatedAt: created,
  );

  TabPayment payment(String id, String tabId, DateTime paid) => TabPayment(
    id: id,
    tabId: tabId,
    amount: 450,
    paidDate: paid,
    createdAt: paid,
    updatedAt: paid,
  );

  late MemoryPayLaterRepository repo;
  late GetActivityExtrasUseCase useCase;
  final today = DateTime(2026, 11, 14);
  final november = budget('b1', DateTime(2026, 11, 1), DateTime(2026, 11, 30));

  setUp(() {
    repo = MemoryPayLaterRepository();
    useCase = GetActivityExtrasUseCase(repo);
  });

  test('names the tab of each purchase in the budgets on screen', () async {
    repo
      ..addTab(tab('t1', 'Cafeteria'))
      ..addPurchase('t1', expense('e1', 'b1', DateTime(2026, 11, 3)))
      ..addPurchase('t1', expense('e2', 'other', DateTime(2026, 11, 3)));

    final extras = await useCase(budgets: [november], today: today);

    expect(extras.tabNameByExpense, {'e1': 'Cafeteria'});
  });

  test('a payment to a tab used in the budget shows, inside its period, '
      'and a tab not used there does not', () async {
    repo
      ..addTab(tab('t1', 'Cafeteria'))
      ..addTab(tab('t2', 'Corner shop'))
      ..addPurchase('t1', expense('e1', 'b1', DateTime(2026, 11, 3)))
      ..payments['p1'] = payment('p1', 't1', DateTime(2026, 11, 10, 18, 5))
      ..payments['p0'] = payment('p0', 't1', DateTime(2026, 10, 20))
      ..payments['p2'] = payment('p2', 't2', DateTime(2026, 11, 11));

    final extras = await useCase(budgets: [november], today: today);
    final payments = extras.items.whereType<TabPaymentExtra>().toList();

    expect(payments, hasLength(1));
    expect(payments.single.id, 'p1');
    expect(payments.single.tabName, 'Cafeteria');
    expect(payments.single.tabId, 't1');
    expect(payments.single.amount, 450);
    expect(payments.single.currency, 'INR');
    expect(payments.single.at, DateTime(2026, 11, 10, 18, 5));
  });

  test('a payment dated without a time takes the time it was recorded '
      'that day', () async {
    repo
      ..addTab(tab('t1', 'Cafeteria'))
      ..addPurchase('t1', expense('e1', 'b1', DateTime(2026, 11, 3)))
      ..payments['p1'] = TabPayment(
        id: 'p1',
        tabId: 't1',
        amount: 450,
        paidDate: DateTime(2026, 11, 10),
        createdAt: DateTime(2026, 11, 10, 19, 30),
        updatedAt: DateTime(2026, 11, 10, 19, 30),
      )
      ..payments['p2'] = TabPayment(
        id: 'p2',
        tabId: 't1',
        amount: 450,
        paidDate: DateTime(2026, 11, 8),
        createdAt: DateTime(2026, 11, 9, 8),
        updatedAt: DateTime(2026, 11, 9, 8),
      );

    final extras = await useCase(budgets: [november], today: today);
    final at = {
      for (final p in extras.items.whereType<TabPaymentExtra>()) p.id: p.at,
    };

    expect(at['p1'], DateTime(2026, 11, 10, 19, 30));
    // Recorded a day later: the time it was recorded isn't when it was paid.
    expect(at['p2'], DateTime(2026, 11, 8));
  });

  test('marks a budget starting, and ending once its end has passed', () async {
    final october = budget('b2', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
    final upcoming = budget(
      'b3',
      DateTime(2026, 12, 1),
      DateTime(2026, 12, 31),
    );

    final extras = await useCase(
      budgets: [november, october, upcoming],
      today: today,
    );
    final markers = extras.items.whereType<BudgetMarkerExtra>().toList();

    expect(
      [for (final m in markers) (m.budgetId, m.started, m.at)],
      unorderedEquals([
        ('b1', true, DateTime(2026, 11, 1)),
        ('b2', true, DateTime(2026, 10, 1)),
        ('b2', false, DateTime(2026, 10, 31)),
      ]),
    );
    final started = markers.firstWhere((m) => m.budgetId == 'b1');
    expect(started.name, 'November');
    expect(started.amount, 30000);
    expect(started.days, 30);
  });

  test('a tab read failure still returns the markers', () async {
    final extras = await GetActivityExtrasUseCase(_UnreadableTabs())(
      budgets: [november],
      today: today,
    );
    expect(extras.items.whereType<BudgetMarkerExtra>(), hasLength(1));
  });
}

class _UnreadableTabs extends MemoryPayLaterRepository {
  @override
  Future<List<PayLaterTab>> getTabs() async => throw StateError('db');
}
