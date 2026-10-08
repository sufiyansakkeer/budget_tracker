import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/settings/domain/services/notification_service.dart';

import '../../../../helpers/safe_to_spend_fakes.dart';

/// The morning notification text: the daily amount for each running budget,
/// and — when nothing is free to spend — why, instead of "₹0".
void main() {
  final today = DateTime(2026, 8, 10);
  final calculator = SafeToSpendCalculator(BudgetCalculationService());

  SafeToSpendEntity engine({
    required double amount,
    required double spentBefore,
    double billDue = 0,
    double? reserved,
    String currency = 'INR',
  }) => calculator.calculate(
    SafeToSpendInput(
      budgetId: 'b1',
      budgetName: 'Food',
      currency: currency,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      today: today,
      budgetAmount: amount,
      periodSpent: spentBefore,
      todaySpent: 0,
      commitments: [
        if (billDue > 0)
          CommitmentOccurrence(
            billId: 'rent',
            title: 'Rent',
            amount: billDue,
            dueDate: DateTime(2026, 8, 20),
          ),
      ],
      reservedAmount: reserved,
    ),
  );

  BudgetDailyLimitEntity limit(SafeToSpendEntity entity, {String? name}) =>
      budgetDailyLimitFor(entity, name: name);

  test('no running budget keeps the existing fallback', () {
    expect(
      NotificationService.morningBody(const []),
      'No budget is running today. Open the app to check your budgets.',
    );
  });

  test('a normal day names the amount (unchanged wording)', () {
    // 22000 over 22 days.
    final body = NotificationService.morningBody([
      limit(engine(amount: 22000, spentBefore: 0)),
    ]);
    expect(body, 'Food: you can safely spend ₹1,000 today.');
  });

  test('the amount never reads higher than what is safe', () {
    // 22015 / 22 = 1000.68…: shown floored, never rounded up to 1,001.
    final body = NotificationService.morningBody([
      limit(engine(amount: 22015, spentBefore: 0)),
    ]);
    expect(body, 'Food: you can safely spend ₹1,000.68 today.');
  });

  test('overcommitted explains the shortfall instead of "₹0"', () {
    final entity = engine(amount: 3000, spentBefore: 2000, billDue: 1500);
    expect(entity.status, SafeToSpendStatus.overcommitted);

    expect(
      NotificationService.morningBody([limit(entity)]),
      "Food: bills and money set aside are ₹500 more than what's left. "
      'Nothing is free to spend today.',
    );
  });

  test('over budget says by how much', () {
    final entity = engine(amount: 3000, spentBefore: 3500);
    expect(entity.status, SafeToSpendStatus.overBudget);

    expect(
      NotificationService.morningBody([limit(entity)]),
      "Food: you've spent ₹500 more than this budget's amount. Nothing is "
      'free to spend today.',
    );
  });

  test('everything set aside says so', () {
    final entity = engine(amount: 3000, spentBefore: 1500, reserved: 1500);
    expect(entity.dailySafeToSpend, 0);

    expect(
      NotificationService.morningBody([limit(entity)]),
      'Food: nothing is free to spend today after bills and money set aside.',
    );
  });

  test('several budgets: one line each, never combined', () {
    final body = NotificationService.morningBody([
      limit(engine(amount: 22000, spentBefore: 0), name: 'Food'),
      limit(
        engine(amount: 3000, spentBefore: 2000, billDue: 1500),
        name: 'Home',
      ),
      limit(engine(amount: 3000, spentBefore: 3500), name: 'Trip'),
    ]);

    expect(
      body,
      "Today's Safe Spending per budget\n\n"
      'Food: ₹1,000\n'
      'Home: ₹500 short\n'
      'Trip: ₹500 over budget',
    );
  });
}
