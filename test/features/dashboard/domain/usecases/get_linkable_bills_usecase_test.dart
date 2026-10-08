import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_linkable_bills_usecase.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart';

import '../../../../helpers/safe_to_spend_fakes.dart';
import 'get_spending_targets_usecase_test.dart' show FakeBudgetRepository;

void main() {
  // House fixture: Aug 2026, evaluated on 10 Aug.
  final clock = DateTime(2026, 8, 10, 9, 15);

  late FakeBudgetRepository budgets;
  late SafeSpendFakeBillRepository bills;
  late GetLinkableBillsUseCase useCase;

  BudgetEntity budget({
    String id = 'aug',
    DateTime? start,
    DateTime? end,
    bool archived = false,
  }) {
    final s = start ?? DateTime(2026, 8, 1);
    return BudgetEntity(
      id: id,
      name: 'Budget $id',
      monthlyAmount: 30000,
      remainingAmount: 30000,
      currency: 'INR',
      startDate: s,
      endDate: end ?? DateTime(2026, 8, 31),
      isArchived: archived,
      createdAt: s,
      updatedAt: s,
    );
  }

  BillEntity bill(
    String id, {
    required DateTime due,
    String? budgetId,
    String currency = 'INR',
    double amount = 500,
  }) => BillEntity(
    id: id,
    title: 'Bill $id',
    amount: amount,
    currency: currency,
    category: BillCategory.utilities,
    dueDate: due,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    budgetId: budgetId,
  );

  setUp(() {
    budgets = FakeBudgetRepository();
    bills = SafeSpendFakeBillRepository();
    useCase = GetLinkableBillsUseCase(
      billRepository: bills,
      budgetRepository: budgets,
      clock: () => clock,
    );
  });

  test('splits the bills the budget does not set aside by currency', () async {
    final july = budget(
      id: 'jul',
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    budgets.budgets = [budget(), july];
    bills.store
      ..['water'] = bill('water', due: DateTime(2026, 8, 25))
      ..['tax'] = bill('tax', due: DateTime(2026, 8, 12), budgetId: 'jul')
      ..['usd'] = bill('usd', due: DateTime(2026, 8, 15), currency: 'USD')
      ..['gym'] = bill('gym', due: DateTime(2026, 8, 20), budgetId: 'aug')
      ..['later'] = bill('later', due: DateTime(2026, 9, 3));

    final result = await useCase(budgetId: 'aug');

    final data = (result as BudgetSuccess<LinkableBills>).data;
    expect(data.budget.id, 'aug');
    expect(data.linkable.map((b) => b.id), ['tax', 'water']);
    expect(data.otherCurrency.map((b) => b.id), ['usd']);
  });

  test('offers exactly what the dashboard counts as not linked', () async {
    budgets.budgets = [budget()];
    bills.store
      ..['a'] = bill('a', due: DateTime(2026, 8, 11), amount: 100)
      ..['b'] = bill('b', due: DateTime(2026, 8, 30), amount: 250);
    final GetSafeToSpendUseCase safeToSpend = fakeSafeToSpendUseCase(
      budgets,
      billRepository: bills,
    );

    final linkable = (await useCase(budgetId: 'aug')) as BudgetSuccess;
    final entity =
        (await safeToSpend(budgetId: 'aug', referenceDate: clock))
            as BudgetSuccess;

    expect(
      (linkable.data as LinkableBills).linkable,
      hasLength(entity.data.unlinked.count),
    );
  });

  test('an archived or missing budget is not found', () async {
    budgets.budgets = [budget(id: 'old', archived: true)];

    expect(await useCase(budgetId: 'old'), isA<BudgetError>());
    expect(await useCase(budgetId: 'nope'), isA<BudgetError>());
  });

  test('a bills read failure is reported to the caller', () async {
    budgets.budgets = [budget()];
    bills.throwOnRead = true;

    expect(useCase(budgetId: 'aug'), throwsException);
  });
}
