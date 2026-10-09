import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/widgets/home_widget_service.dart';
import 'package:monivo/features/widgets/widget_refresh_listener.dart';

import '../dashboard/domain/usecases/get_spending_targets_usecase_test.dart'
    show FakeBudgetRepository;
import '../../helpers/safe_to_spend_fakes.dart';

/// The home-screen widget's status string comes from the safe-to-spend
/// engine: a running budget with nothing free to spend is "short", never
/// "no budget".
void main() {
  group('widget amounts', () {
    test('what is left rounds down, so the widget never promises more', () {
      expect(HomeWidgetService.unitsLeft(41.66), '41');
      expect(HomeWidgetService.unitsLeft(41.999), '41');
      expect(HomeWidgetService.unitsLeft(42), '42');
      // Float noise from the engine does not cost a unit.
      expect(HomeWidgetService.unitsLeft(41.9999999999), '42');
      expect(HomeWidgetService.unitsLeft(0), '0');
      expect(HomeWidgetService.unitsLeft(-12.4), '-13');
    });
  });

  final today = DateTime(2026, 8, 10);
  final calculator = SafeToSpendCalculator(BudgetCalculationService());

  /// Aug 1–31, 22 days left including today.
  SafeToSpendEntity engine({
    double amount = 22000,
    double spentBefore = 0,
    double spentToday = 0,
    double billDue = 0,
    List<CommitmentOccurrence>? commitments = const [],
  }) => calculator.calculate(
    SafeToSpendInput(
      budgetId: 'b1',
      budgetName: 'Food',
      currency: 'INR',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      today: today,
      budgetAmount: amount,
      periodSpent: spentBefore + spentToday,
      todaySpent: spentToday,
      commitments: billDue > 0
          ? [
              CommitmentOccurrence(
                billId: 'rent',
                title: 'Rent',
                amount: billDue,
                dueDate: DateTime(2026, 8, 20),
              ),
            ]
          : commitments,
    ),
  );

  String statusOf(SafeToSpendEntity entity) =>
      HomeWidgetService.statusFor(budgetDailyLimitFor(entity));

  group('HomeWidgetService.statusFor', () {
    test('on track', () {
      final entity = engine(spentToday: 100);
      expect(entity.status, SafeToSpendStatus.onTrack);
      expect(statusOf(entity), 'on_track');
    });

    test('over today\'s amount carries the overspend', () {
      // Daily 1000; 1250.40 spent today.
      final entity = engine(spentToday: 1250.40);
      expect(entity.status, SafeToSpendStatus.overDailyAllowance);
      expect(statusOf(entity), 'over:251');
    });

    test('overcommitted is "short", not "no budget"', () {
      final entity = engine(amount: 3000, spentBefore: 2000, billDue: 1500);
      expect(entity.status, SafeToSpendStatus.overcommitted);
      expect(entity.dailySafeToSpend, 0);
      expect(statusOf(entity), 'short:500');
    });

    test('over budget is "short" by the shortfall', () {
      final entity = engine(amount: 3000, spentBefore: 3200.25);
      expect(entity.status, SafeToSpendStatus.overBudget);
      expect(statusOf(entity), 'short:201');
    });

    test('spending carefully and at risk are "careful"', () {
      // Bills unavailable caps the status at spendingCarefully.
      final unavailable = engine(commitments: null);
      expect(unavailable.status, SafeToSpendStatus.spendingCarefully);
      expect(statusOf(unavailable), 'careful');

      // 9 completed days at 2000/day against 31000: projected short.
      final atRisk = calculator.calculate(
        SafeToSpendInput(
          budgetId: 'b1',
          budgetName: 'Food',
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          today: today,
          budgetAmount: 31000,
          periodSpent: 18000,
          todaySpent: 0,
          commitments: const [],
        ),
      );
      expect(atRisk.status, SafeToSpendStatus.budgetAtRisk);
      expect(statusOf(atRisk), 'careful');
    });
  });

  test('the widget listener refreshes on bill changes too', () async {
    final service = _CountingWidgetService();
    final listener = WidgetRefreshListener(widgetService: service)
      ..startListening();
    addTearDown(listener.stopListening);

    RefreshBuses.bills.notifyChanged();
    RefreshBuses.expenses.notifyChanged();
    RefreshBuses.budgets.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(service.updates, 3);

    listener.stopListening();
    RefreshBuses.bills.notifyChanged();
    await Future<void>.delayed(Duration.zero);
    expect(service.updates, 3);
  });
}

/// Counts update requests instead of writing to the platform widget store.
class _CountingWidgetService extends HomeWidgetService {
  _CountingWidgetService() : this._(FakeBudgetRepository());

  _CountingWidgetService._(FakeBudgetRepository repository)
    : super(
        budgetRepository: repository,
        getSpendingTargetsUseCase: GetSpendingTargetsUseCase(
          repository: repository,
          calculationService: BudgetCalculationService(),
          safeToSpend: fakeSafeToSpendUseCase(repository),
        ),
      );

  int updates = 0;

  @override
  Future<void> updateWidgetData({DateTime? referenceDate}) async => updates++;
}
