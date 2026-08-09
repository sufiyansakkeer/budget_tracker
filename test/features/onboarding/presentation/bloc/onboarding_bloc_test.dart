import 'package:bloc_test/bloc_test.dart';
import 'package:budget_tracker/core/domain/entities/budget_entity.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_error.dart';
import 'package:budget_tracker/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_filter.dart';
import 'package:budget_tracker/features/budget/domain/repository/budget_repository.dart';
import 'package:budget_tracker/features/onboarding/domain/entities/budget_entity.dart'
    as onboarding;
import 'package:budget_tracker/features/onboarding/domain/repository/onboarding_repository.dart';
import 'package:budget_tracker/features/onboarding/domain/usecases/create_budget_usecase.dart';
import 'package:budget_tracker/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:budget_tracker/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:budget_tracker/features/onboarding/presentation/bloc/onboarding_state.dart';
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
}

void main() {
  late FakeOnboardingRepository onboardingRepository;
  late FakeBudgetRepository budgetRepository;
  late CreateBudgetUseCase createBudgetUseCase;

  setUp(() {
    onboardingRepository = FakeOnboardingRepository();
    budgetRepository = FakeBudgetRepository();
    createBudgetUseCase = CreateBudgetUseCase(onboardingRepository);
  });

  OnboardingBloc buildBloc() => OnboardingBloc(
    createBudgetUseCase: createBudgetUseCase,
    budgetRepository: budgetRepository,
  );

  group('Budget input INVALID -> VALID transition', () {
    blocTest<OnboardingBloc, OnboardingState>(
      'entering a valid budget enables continue',
      build: buildBloc,
      act: (bloc) => bloc.add(const OnboardingBudgetInputChangedEvent('30000')),
      expect: () => [
        isA<OnboardingState>()
            .having((s) => s.parsedBudget, 'parsedBudget', 30000.0)
            .having((s) => s.budgetValidationError, 'error', isNull)
            .having((s) => s.isBudgetValid, 'isBudgetValid', isTrue),
      ],
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'clearing input sets error and disables continue',
      build: buildBloc,
      act: (bloc) {
        bloc.add(const OnboardingBudgetInputChangedEvent('30000'));
        bloc.add(const OnboardingBudgetInputChangedEvent(''));
      },
      expect: () => [
        isA<OnboardingState>()
            .having((s) => s.parsedBudget, 'parsedBudget', 30000.0)
            .having((s) => s.isBudgetValid, 'isBudgetValid', isTrue),
        isA<OnboardingState>()
            .having((s) => s.parsedBudget, 'parsedBudget', isNull)
            .having((s) => s.isBudgetValid, 'isBudgetValid', isFalse)
            .having((s) => s.budgetValidationError, 'error', isNotEmpty),
      ],
    );

    blocTest<OnboardingBloc, OnboardingState>(
      're-entering a valid budget after clearing clears error and re-enables continue',
      build: buildBloc,
      act: (bloc) {
        bloc.add(const OnboardingBudgetInputChangedEvent('30000'));
        bloc.add(const OnboardingBudgetInputChangedEvent(''));
        bloc.add(const OnboardingBudgetInputChangedEvent('30000'));
      },
      expect: () => [
        isA<OnboardingState>()
            .having((s) => s.parsedBudget, 'parsedBudget', 30000.0)
            .having((s) => s.isBudgetValid, 'isBudgetValid', isTrue),
        isA<OnboardingState>()
            .having((s) => s.parsedBudget, 'parsedBudget', isNull)
            .having((s) => s.isBudgetValid, 'isBudgetValid', isFalse),
        isA<OnboardingState>()
            .having((s) => s.parsedBudget, 'parsedBudget', 30000.0)
            .having((s) => s.budgetValidationError, 'error', isNull)
            .having((s) => s.isBudgetValid, 'isBudgetValid', isTrue),
      ],
    );

    blocTest<OnboardingBloc, OnboardingState>(
      're-entering a different valid budget after clearing re-enables continue',
      build: buildBloc,
      act: (bloc) {
        bloc.add(const OnboardingBudgetInputChangedEvent('30000'));
        bloc.add(const OnboardingBudgetInputChangedEvent(''));
        bloc.add(const OnboardingBudgetInputChangedEvent('50000'));
      },
      expect: () => [
        isA<OnboardingState>().having(
          (s) => s.parsedBudget,
          'parsedBudget',
          30000.0,
        ),
        isA<OnboardingState>()
            .having((s) => s.parsedBudget, 'parsedBudget', isNull)
            .having((s) => s.isBudgetValid, 'isBudgetValid', isFalse),
        isA<OnboardingState>()
            .having((s) => s.parsedBudget, 'parsedBudget', 50000.0)
            .having((s) => s.budgetValidationError, 'error', isNull)
            .having((s) => s.isBudgetValid, 'isBudgetValid', isTrue),
      ],
    );
  });

  group('Name input INVALID -> VALID transition', () {
    blocTest<OnboardingBloc, OnboardingState>(
      'clearing name sets error and re-entering clears it',
      build: buildBloc,
      act: (bloc) {
        bloc.add(const OnboardingBudgetNameChangedEvent('Personal'));
        bloc.add(const OnboardingBudgetNameChangedEvent(''));
        bloc.add(const OnboardingBudgetNameChangedEvent('Personal'));
      },
      expect: () => [
        isA<OnboardingState>().having(
          (s) => s.isNameValid,
          'isNameValid',
          isTrue,
        ),
        isA<OnboardingState>()
            .having((s) => s.isNameValid, 'isNameValid', isFalse)
            .having((s) => s.nameValidationError, 'error', isNotEmpty),
        isA<OnboardingState>()
            .having((s) => s.isNameValid, 'isNameValid', isTrue)
            .having((s) => s.nameValidationError, 'error', isNull),
      ],
    );
  });

  group('Date input INVALID -> VALID transition', () {
    blocTest<OnboardingBloc, OnboardingState>(
      'invalid end date sets error and a later end date clears it',
      build: buildBloc,
      act: (bloc) {
        final start = DateTime(2026, 8, 1);
        bloc.add(OnboardingStartDateChangedEvent(start));
        bloc.add(OnboardingEndDateChangedEvent(DateTime(2026, 8, 1)));
        bloc.add(OnboardingEndDateChangedEvent(DateTime(2026, 8, 31)));
      },
      expect: () => [
        isA<OnboardingState>().having(
          (s) => s.isDateRangeValid,
          'isDateRangeValid',
          isTrue,
        ),
        isA<OnboardingState>()
            .having((s) => s.isDateRangeValid, 'isDateRangeValid', isFalse)
            .having((s) => s.dateValidationError, 'error', isNotEmpty),
        isA<OnboardingState>()
            .having((s) => s.isDateRangeValid, 'isDateRangeValid', isTrue)
            .having((s) => s.dateValidationError, 'error', isNull),
      ],
    );
  });

  group('Submit', () {
    blocTest<OnboardingBloc, OnboardingState>(
      'valid form proceeds to success and persists budget',
      build: buildBloc,
      seed: () => OnboardingState(
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
        budgetNameInput: 'Personal',
        monthlyBudgetInput: '30000',
        parsedBudget: 30000.0,
      ),
      act: (bloc) => bloc.add(const OnboardingSubmittedEvent()),
      expect: () => [
        isA<OnboardingState>().having(
          (s) => s.status,
          'status',
          OnboardingStatus.loading,
        ),
        isA<OnboardingState>().having(
          (s) => s.status,
          'status',
          OnboardingStatus.success,
        ),
      ],
      verify: (bloc) {
        expect(onboardingRepository.createdBudget, isNotNull);
        expect(onboardingRepository.createdBudget!.monthlyAmount, 30000.0);
        expect(onboardingRepository.isFirstLaunch, isFalse);
      },
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'invalid form does not proceed',
      build: buildBloc,
      seed: () => OnboardingState(
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
        budgetNameInput: 'Personal',
        monthlyBudgetInput: '30000',
        parsedBudget: 30000.0,
        budgetValidationError: 'Budget amount cannot be empty',
      ),
      act: (bloc) => bloc.add(const OnboardingSubmittedEvent()),
      expect: () => [
        isA<OnboardingState>()
            .having((s) => s.status, 'status', OnboardingStatus.failure)
            .having((s) => s.errorMessage, 'error', isNotNull),
      ],
      verify: (bloc) {
        expect(onboardingRepository.createdBudget, isNull);
      },
    );
  });
}
