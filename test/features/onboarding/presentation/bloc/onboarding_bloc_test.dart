import 'package:bloc_test/bloc_test.dart';
import 'package:monivo/core/currency/currency_provider.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart' as onboarding;
import 'package:monivo/features/onboarding/domain/repository/onboarding_repository.dart';
import 'package:monivo/features/onboarding/domain/usecases/create_budget_usecase.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/repository/settings_repository.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/update_currency_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  bool isFirstLaunch = true;
  onboarding.BudgetEntity? createdBudget;
  final createdIds = <String>{};

  @override
  Future<bool> checkIsFirstLaunch() async => isFirstLaunch;

  @override
  Future<void> setFirstLaunchCompleted() async {
    isFirstLaunch = false;
  }

  @override
  Future<void> createInitialBudget(onboarding.BudgetEntity budget) async {
    createdBudget = budget;
    createdIds.add(budget.id);
  }
}

class FakeBudgetRepository implements BudgetRepository {
  /// How many of the next setActiveBudgetId calls fail.
  int failActivations = 0;
  String? activeId;

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();

  @override
  Future<BudgetEntity?> getActiveBudget() async => null;

  @override
  Future<String?> getActiveBudgetId() async => null;

  @override
  Future<void> setActiveBudgetId(String budgetId) async {
    if (failActivations > 0) {
      failActivations--;
      throw StateError('preferences unavailable');
    }
    activeId = budgetId;
  }

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

class FakeSettingsRepository extends Fake implements SettingsRepository {
  String? savedCode;
  String? savedSymbol;

  @override
  Future<AppSettings> loadSettings() async => const AppSettings();

  @override
  Future<void> setCurrency(String code, String symbol) async {
    savedCode = code;
    savedSymbol = symbol;
  }
}

void main() {
  late FakeOnboardingRepository onboardingRepository;
  late FakeBudgetRepository budgetRepository;
  late FakeSettingsRepository settingsRepository;
  late CreateBudgetUseCase createBudgetUseCase;
  late CurrencyProvider currencyProvider;

  setUp(() {
    onboardingRepository = FakeOnboardingRepository();
    budgetRepository = FakeBudgetRepository();
    settingsRepository = FakeSettingsRepository();
    createBudgetUseCase = CreateBudgetUseCase(onboardingRepository);
    currencyProvider = CurrencyProvider(
      loadSettingsUseCase: LoadSettingsUseCase(repository: settingsRepository),
    );
  });

  OnboardingBloc buildBloc() => OnboardingBloc(
    createBudgetUseCase: createBudgetUseCase,
    budgetRepository: budgetRepository,
    updateCurrencyUseCase: UpdateCurrencyUseCase(
      repository: settingsRepository,
    ),
    currencyProvider: currencyProvider,
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

    test('a failed step leaves onboarding open, and a retry makes no second '
        'budget', () async {
      budgetRepository.failActivations = 1;
      final bloc = buildBloc()
        ..emit(
          OnboardingState(
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 8, 31),
            budgetNameInput: 'Personal',
            monthlyBudgetInput: '30000',
            parsedBudget: 30000.0,
          ),
        );

      bloc.add(const OnboardingSubmittedEvent());
      await bloc.stream.firstWhere((s) => s.status == OnboardingStatus.failure);
      // Not marked done: the app would leave onboarding with no active
      // budget.
      expect(onboardingRepository.isFirstLaunch, isTrue);

      bloc.add(const OnboardingSubmittedEvent());
      await bloc.stream.firstWhere((s) => s.status == OnboardingStatus.success);

      expect(onboardingRepository.createdIds, hasLength(1));
      expect(budgetRepository.activeId, onboardingRepository.createdIds.single);
      expect(onboardingRepository.isFirstLaunch, isFalse);
      await bloc.close();
    });

    test('the chosen currency becomes the app default (UX-016)', () async {
      // Let the provider's first settings read land before the submit.
      await Future<void>.delayed(Duration.zero);
      final bloc = buildBloc()
        ..emit(
          OnboardingState(
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 8, 31),
            budgetNameInput: 'Personal',
            monthlyBudgetInput: '30',
            parsedBudget: 30.0,
          ),
        )
        ..add(const OnboardingCurrencySelectedEvent(code: 'OMR', symbol: 'OMR'))
        ..add(const OnboardingSubmittedEvent());
      await bloc.stream.firstWhere((s) => s.status == OnboardingStatus.success);

      expect(onboardingRepository.createdBudget!.currency, 'OMR');
      expect(settingsRepository.savedCode, 'OMR');
      expect(currencyProvider.currencyCode, 'OMR');
      await bloc.close();
    });

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

  group('dates are calendar dates (review: the first budget stored the '
      'moment onboarding ran)', () {
    bool isDateOnly(DateTime d) => d == DateTime(d.year, d.month, d.day);

    test(
      'the default period is today plus 30 calendar days, no time of day',
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const OnboardingInitEvent());
        final state = await bloc.stream.first;

        expect(isDateOnly(state.startDate), isTrue);
        expect(isDateOnly(state.endDate), isTrue);
        final s = state.startDate;
        expect(state.endDate, DateTime(s.year, s.month, s.day + 30));
        expect(isDateOnly(bloc.state.startDate), isTrue);
      },
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'picked dates are stored without their time of day',
      build: buildBloc,
      act: (bloc) {
        bloc.add(
          OnboardingStartDateChangedEvent(DateTime(2026, 10, 8, 11, 20)),
        );
        bloc.add(OnboardingEndDateChangedEvent(DateTime(2026, 10, 31, 18, 5)));
      },
      skip: 1,
      expect: () => [
        isA<OnboardingState>()
            .having((s) => s.startDate, 'startDate', DateTime(2026, 10, 8))
            .having((s) => s.endDate, 'endDate', DateTime(2026, 10, 31)),
      ],
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'a start after the end keeps the period length (UX-044)',
      build: buildBloc,
      seed: () => OnboardingState(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 5),
      ),
      act: (bloc) =>
          bloc.add(OnboardingStartDateChangedEvent(DateTime(2026, 3, 7, 23))),
      expect: () => [
        isA<OnboardingState>()
            .having((s) => s.startDate, 'startDate', DateTime(2026, 3, 7))
            .having((s) => s.endDate, 'endDate', DateTime(2026, 3, 11)),
      ],
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'moving the start later keeps the period length, not the end '
      '(UX-044)',
      // The audit's repro: 10 Oct to 9 Nov, start moved to 1 Nov, gave a
      // 9-day budget.
      build: buildBloc,
      seed: () => OnboardingState(
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 11, 9),
      ),
      act: (bloc) =>
          bloc.add(OnboardingStartDateChangedEvent(DateTime(2026, 11, 1))),
      expect: () => [
        isA<OnboardingState>()
            .having((s) => s.startDate, 'startDate', DateTime(2026, 11, 1))
            .having((s) => s.endDate, 'endDate', DateTime(2026, 12, 1)),
      ],
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'a start moved after an invalid end gives a one-day-long period',
      build: buildBloc,
      seed: () => OnboardingState(
        startDate: DateTime(2026, 3, 5),
        endDate: DateTime(2026, 3, 2),
        dateValidationError: 'End date must be after start date',
      ),
      act: (bloc) =>
          bloc.add(OnboardingStartDateChangedEvent(DateTime(2026, 3, 6))),
      expect: () => [
        isA<OnboardingState>()
            .having((s) => s.endDate, 'endDate', DateTime(2026, 3, 7))
            .having((s) => s.dateValidationError, 'error', isNull),
      ],
    );
  });

  group('UX-042: a backup restored on Welcome finishes onboarding', () {
    test('onboarding is marked done and leaves for Home, with no budget '
        'made', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const OnboardingRestoredEvent());
      final done = await bloc.stream.firstWhere(
        (s) => s.status == OnboardingStatus.success,
      );

      expect(done.status, OnboardingStatus.success);
      expect(onboardingRepository.isFirstLaunch, isFalse);
      expect(onboardingRepository.createdBudget, isNull);
    });
  });

  group('the amount follows the budget rules', () {
    test('an amount past the limit is refused, not taken on', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(
        const OnboardingCurrencySelectedEvent(code: 'OMR', symbol: 'OMR'),
      );
      bloc.add(const OnboardingBudgetInputChangedEvent('10000000000000'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.parsedBudget, isNull);
      expect(bloc.state.budgetValidationError, isNotNull);
    });

    test('changing the currency checks the amount again', () async {
      // 12.125 is fine in OMR (three decimals) but not in INR (two).
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(
        const OnboardingCurrencySelectedEvent(code: 'OMR', symbol: 'OMR'),
      );
      bloc.add(const OnboardingBudgetInputChangedEvent('12.125'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.parsedBudget, 12.125);

      bloc.add(const OnboardingCurrencySelectedEvent(code: 'INR', symbol: '₹'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.parsedBudget, isNull);
      expect(bloc.state.budgetValidationError, isNotNull);
    });
  });
}
