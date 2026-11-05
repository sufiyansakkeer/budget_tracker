import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../budget/domain/repository/budget_repository.dart';
import '../../../../core/currency/currency_provider.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../domain/usecases/create_budget_usecase.dart';
import 'onboarding_event.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../../settings/domain/entities/settings_failure.dart';
import '../../../settings/domain/usecases/update_currency_usecase.dart';
import 'onboarding_state.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/currency/money_input.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/errors/user_facing_error.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final CreateBudgetUseCase createBudgetUseCase;
  final BudgetRepository budgetRepository;
  final UpdateCurrencyUseCase updateCurrencyUseCase;
  final CurrencyProvider currencyProvider;

  /// One id for every submit, so a retry rewrites the same budget.
  final String _budgetId = const Uuid().v4();

  OnboardingBloc({
    required this.createBudgetUseCase,
    required this.budgetRepository,
    required this.updateCurrencyUseCase,
    required this.currencyProvider,
  }) : super(
         OnboardingState(startDate: _today(), endDate: _today().addDays(30)),
       ) {
    on<OnboardingInitEvent>(_onInit);
    on<OnboardingPageChangedEvent>(_onPageChanged);
    on<OnboardingBudgetNameChangedEvent>(_onBudgetNameChanged);
    on<OnboardingBudgetInputChangedEvent>(_onBudgetInputChanged);
    on<OnboardingCurrencySelectedEvent>(_onCurrencySelected);
    on<OnboardingStartDateChangedEvent>(_onStartDateChanged);
    on<OnboardingEndDateChangedEvent>(_onEndDateChanged);
    on<OnboardingSubmittedEvent>(_onSubmitted);
    on<OnboardingRestoredEvent>(_onRestored);
  }

  void _onInit(OnboardingInitEvent event, Emitter<OnboardingState> emit) {
    final today = _today();
    emit(
      state.copyWith(
        startDate: today,
        endDate: today.addDays(30),
        selectedCurrency: _detectCurrency(event.localeCountryCode),
      ),
    );
  }

  CurrencyEntity _detectCurrency(String? localeCountryCode) {
    if (localeCountryCode == null) return availableCurrencies.first;
    final code = localeCountryCode.toUpperCase();
    for (final currency in availableCurrencies) {
      final countryToCurrency = _countryToCurrency();
      if (countryToCurrency[code] == currency.code) return currency;
    }
    return availableCurrencies.first;
  }

  Map<String, String> _countryToCurrency() {
    return {
      'IN': 'INR',
      'US': 'USD',
      'AE': 'AED',
      'OM': 'OMR',
      'GB': 'GBP',
      'CA': 'CAD',
      'AU': 'AUD',
      'JP': 'JPY',
      'SG': 'SGD',
    };
  }

  void _onPageChanged(
    OnboardingPageChangedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(currentPageIndex: event.pageIndex));
  }

  void _onBudgetNameChanged(
    OnboardingBudgetNameChangedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    final name = event.name.trim();
    if (name.isEmpty) {
      emit(
        state.copyWith(
          budgetNameInput: event.name,
          nameValidationError: 'Budget name cannot be empty',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        budgetNameInput: event.name,
        clearNameValidationError: true,
      ),
    );
  }

  void _onBudgetInputChanged(
    OnboardingBudgetInputChangedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    _applyBudgetInput(event.budgetInput, emit);
  }

  /// Checks [rawInput] against the budget rules for the chosen currency and
  /// stores it. Run again when the currency changes: 12.125 is fine in OMR
  /// but not in INR.
  void _applyBudgetInput(String rawInput, Emitter<OnboardingState> emit) {
    final input = rawInput.trim();
    final value = double.tryParse(input);
    final error = input.isEmpty
        ? 'Budget amount cannot be empty'
        : value == null
        ? 'Please enter a valid number'
        : value <= 0
        ? 'Budget must be greater than zero'
        : !MoneyMath.isWithinLimit(value)
        ? 'Budget amount must be less than ${MoneyMath.maxAmountLabel}.'
        : MoneyInput.decimalsError(
            input,
            state.selectedCurrency.code,
            subject: 'Budget',
          );
    if (error != null) {
      emit(
        state.copyWith(
          monthlyBudgetInput: input,
          clearParsedBudget: true,
          budgetValidationError: error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        monthlyBudgetInput: input,
        parsedBudget: value,
        clearBudgetValidationError: true,
      ),
    );
  }

  void _onCurrencySelected(
    OnboardingCurrencySelectedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    final found = availableCurrencies.firstWhere(
      (c) => c.code == event.code,
      orElse: () => CurrencyEntity(
        code: event.code,
        symbol: event.symbol,
        name: event.code,
      ),
    );
    emit(state.copyWith(selectedCurrency: found));
    if (state.monthlyBudgetInput.isNotEmpty) {
      _applyBudgetInput(state.monthlyBudgetInput, emit);
    }
  }

  void _onStartDateChanged(
    OnboardingStartDateChangedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    final newStart = event.date.dateOnly;
    // Keep the same number of days when the start moves, as the budget
    // form does: keeping the end shortened the period without saying so.
    final length = calendarDaysBetween(state.startDate, state.endDate);
    final newEnd = newStart.addDays(length < 1 ? 1 : length);
    emit(
      state.copyWith(
        startDate: newStart,
        endDate: newEnd,
        clearDateValidationError: true,
      ),
    );
  }

  void _onEndDateChanged(
    OnboardingEndDateChangedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    final newEnd = event.date.dateOnly;
    if (!newEnd.isAfter(state.startDate)) {
      emit(
        state.copyWith(
          endDate: newEnd,
          dateValidationError: 'End date must be after start date',
        ),
      );
      return;
    }
    emit(state.copyWith(endDate: newEnd, clearDateValidationError: true));
  }

  Future<void> _onSubmitted(
    OnboardingSubmittedEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    if (!state.isAllValid) {
      emit(
        state.copyWith(
          status: OnboardingStatus.failure,
          errorMessage:
              state.budgetValidationError ??
              state.nameValidationError ??
              state.dateValidationError ??
              'Please complete all budget details',
        ),
      );
      return;
    }

    emit(
      state.copyWith(status: OnboardingStatus.loading, clearErrorMessage: true),
    );

    try {
      final now = DateTime.now();
      final budgetEntity = BudgetEntity(
        id: _budgetId,
        name: state.budgetNameInput.trim(),
        monthlyAmount: state.parsedBudget!,
        remainingAmount: state.parsedBudget!,
        currency: state.selectedCurrency.code,
        startDate: state.startDate,
        endDate: state.endDate,
        createdAt: now,
        updatedAt: now,
      );

      // Budget, then active budget, then default currency, then
      // "onboarding done": the app leaves onboarding only once the budget is
      // in place. Preferences and the database can't share a transaction,
      // so a failed step is retried from the start, and the fixed id keeps
      // that to one budget.
      final currency = state.selectedCurrency;
      await createBudgetUseCase(budgetEntity);
      await budgetRepository.setActiveBudgetId(budgetEntity.id);
      // The chosen currency is also the default for later budgets.
      final saved = await updateCurrencyUseCase(currency.code, currency.symbol);
      if (saved case SettingsError(:final failure)) throw failure.message;
      currencyProvider.updateCurrency(currency.code, currency.symbol);
      await createBudgetUseCase.finishOnboarding();

      emit(state.copyWith(status: OnboardingStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: OnboardingStatus.failure,
          errorMessage: userFacingError(
            '$e',
            forPeople: false,
            fallback: "Couldn't create your budget. Try again.",
          ),
        ),
      );
    }
  }

  Future<void> _onRestored(
    OnboardingRestoredEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(
      state.copyWith(status: OnboardingStatus.loading, clearErrorMessage: true),
    );
    try {
      await createBudgetUseCase.finishOnboarding();
      emit(state.copyWith(status: OnboardingStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: OnboardingStatus.failure,
          errorMessage: userFacingError(
            '$e',
            forPeople: false,
            fallback:
                "Backup restored, but couldn't finish setting up. Try "
                'again.',
          ),
        ),
      );
    }
  }

  // Budget periods are calendar dates. Storing the moment onboarding ran
  // gave the first budget a time of day, which day counts done on raw
  // timestamps (week share, "Day X of N", this preview) got wrong by one.
  static DateTime _today() => DateTime.now().dateOnly;
}
