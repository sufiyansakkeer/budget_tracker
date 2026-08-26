import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/onboarding/domain/entities/budget_entity.dart'
    as onboarding;
import 'package:monivo/features/onboarding/domain/repository/onboarding_repository.dart';
import 'package:monivo/features/onboarding/domain/usecases/create_budget_usecase.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:monivo/features/onboarding/presentation/widgets/budget_step_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  bool isFirstLaunch = true;
  onboarding.BudgetEntity? createdBudget;

  @override
  Future<bool> checkIsFirstLaunch() async => isFirstLaunch;

  @override
  Future<void> setFirstLaunchCompleted() async {
    isFirstLaunch = false;
  }

  @override
  Future<void> createInitialBudget(onboarding.BudgetEntity budget) async {
    createdBudget = budget;
  }
}

class FakeBudgetRepository implements BudgetRepository {
  @override
  Future<BudgetEntity?> getActiveBudget() async => null;

  @override
  Future<String?> getActiveBudgetId() async => null;

  @override
  Future<void> setActiveBudgetId(String budgetId) async {}

  @override
  Future<BudgetEntity?> getBudgetById(String id) async => null;

  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async => [];

  @override
  Future<BudgetEntity> createBudget(BudgetEntity budget) async => budget;

  @override
  Future<BudgetEntity> updateBudget(BudgetEntity budget) async => budget;

  @override
  Future<void> deleteBudget(String id) async {}

  @override
  Future<BudgetEntity> setBudgetArchived(
    String id, {
    required bool archived,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => MonthlyStatisticsEntity.empty;

  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 0;

  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 1;

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}

  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => 0.0;
}

/// Mimics the real OnboardingScreen wiring: reads BLoC state and passes the
/// error message down to BudgetStepWidget.
class BudgetStepHarness extends StatelessWidget {
  final VoidCallback onContinue;
  const BudgetStepHarness({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (context, state) {
        return BudgetStepWidget(
          initialValue: state.monthlyBudgetInput,
          currencySymbol: state.selectedCurrency.symbol,
          errorMessage: state.budgetValidationError,
          onChanged: (val) => context.read<OnboardingBloc>().add(
            OnboardingBudgetInputChangedEvent(val),
          ),
          onContinue: onContinue,
          onBack: () {},
        );
      },
    );
  }
}

void main() {
  late OnboardingBloc bloc;
  late FakeOnboardingRepository onboardingRepository;
  late FakeBudgetRepository budgetRepository;

  setUp(() {
    onboardingRepository = FakeOnboardingRepository();
    budgetRepository = FakeBudgetRepository();
    bloc = OnboardingBloc(
      createBudgetUseCase: CreateBudgetUseCase(onboardingRepository),
      budgetRepository: budgetRepository,
    );
  });

  tearDown(() {
    bloc.close();
  });

  Widget createHarness({required VoidCallback onContinue}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider.value(
        value: bloc,
        child: Scaffold(body: BudgetStepHarness(onContinue: onContinue)),
      ),
    );
  }

  ElevatedButton continueButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find.byKey(const Key('budgetStepContinueButton')),
      );

  testWidgets(
    'Continue button re-enables after clear -> error -> re-enter valid value',
    (tester) async {
      int continuePressed = 0;
      await tester.pumpWidget(
        createHarness(onContinue: () => continuePressed++),
      );

      final field = find.byKey(const Key('monthlyBudgetTextField'));

      // 1. Enter valid value.
      await tester.enterText(field, '30000');
      await tester.pumpAndSettle();
      expect(
        continueButton(tester).enabled,
        isTrue,
        reason: 'Continue should be enabled for valid input',
      );

      // 2. Clear the field completely.
      await tester.enterText(field, '');
      await tester.pumpAndSettle();
      expect(
        continueButton(tester).enabled,
        isFalse,
        reason: 'Continue should be disabled after clearing',
      );
      expect(
        bloc.state.budgetValidationError,
        'Budget amount cannot be empty',
        reason: 'Validation error should appear in state after clearing',
      );

      // 3. Enter the same valid value again.
      await tester.enterText(field, '30000');
      await tester.pumpAndSettle();
      expect(
        bloc.state.budgetValidationError,
        isNull,
        reason: 'Validation error should clear after valid re-entry',
      );
      expect(
        continueButton(tester).enabled,
        isTrue,
        reason: 'Continue should re-enable after valid re-entry',
      );

      // 4. Tapping continue should work.
      await tester.tap(find.byKey(const Key('budgetStepContinueButton')));
      await tester.pump();
      expect(continuePressed, 1, reason: 'Continue should actually fire');
    },
  );

  testWidgets('Continue re-enables after re-entering a different valid value', (
    tester,
  ) async {
    int continuePressed = 0;
    await tester.pumpWidget(createHarness(onContinue: () => continuePressed++));

    final field = find.byKey(const Key('monthlyBudgetTextField'));

    await tester.enterText(field, '30000');
    await tester.pumpAndSettle();
    expect(continueButton(tester).enabled, isTrue);

    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(continueButton(tester).enabled, isFalse);

    await tester.enterText(field, '50000');
    await tester.pumpAndSettle();
    expect(
      continueButton(tester).enabled,
      isTrue,
      reason: 'Continue should re-enable with a different valid value',
    );

    await tester.tap(find.byKey(const Key('budgetStepContinueButton')));
    await tester.pump();
    expect(continuePressed, 1);
  });

  testWidgets('Continue re-enables after multiple clear cycles', (
    tester,
  ) async {
    int continuePressed = 0;
    await tester.pumpWidget(createHarness(onContinue: () => continuePressed++));

    final field = find.byKey(const Key('monthlyBudgetTextField'));

    await tester.enterText(field, '30000');
    await tester.pumpAndSettle();
    expect(continueButton(tester).enabled, isTrue);

    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(continueButton(tester).enabled, isFalse);

    await tester.enterText(field, '1000');
    await tester.pumpAndSettle();
    expect(continueButton(tester).enabled, isTrue);

    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(continueButton(tester).enabled, isFalse);

    await tester.enterText(field, '5000');
    await tester.pumpAndSettle();
    expect(continueButton(tester).enabled, isTrue);

    await tester.tap(find.byKey(const Key('budgetStepContinueButton')));
    await tester.pump();
    expect(continuePressed, 1);
  });
}
