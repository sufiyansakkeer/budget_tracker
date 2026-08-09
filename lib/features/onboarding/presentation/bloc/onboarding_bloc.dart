import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../budget/domain/repository/budget_repository.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/usecases/create_budget_usecase.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

const List<CurrencyItem> availableCurrencies = [
  CurrencyItem(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
  CurrencyItem(code: 'USD', symbol: '\$', name: 'US Dollar'),
  CurrencyItem(code: 'EUR', symbol: '€', name: 'Euro'),
  CurrencyItem(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
  CurrencyItem(code: 'OMR', symbol: 'ر.ع.', name: 'Omani Rial'),
  CurrencyItem(code: 'GBP', symbol: '£', name: 'British Pound'),
  CurrencyItem(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
  CurrencyItem(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
  CurrencyItem(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  CurrencyItem(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
];

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final CreateBudgetUseCase createBudgetUseCase;
  final BudgetRepository budgetRepository;

  OnboardingBloc({
    required this.createBudgetUseCase,
    required this.budgetRepository,
  }) : super(
         OnboardingState(
           startDate: DateTime.now(),
           endDate: DateTime.now().add(const Duration(days: 30)),
         ),
       ) {
    on<OnboardingInitEvent>(_onInit);
    on<OnboardingPageChangedEvent>(_onPageChanged);
    on<OnboardingBudgetNameChangedEvent>(_onBudgetNameChanged);
    on<OnboardingBudgetInputChangedEvent>(_onBudgetInputChanged);
    on<OnboardingCurrencySelectedEvent>(_onCurrencySelected);
    on<OnboardingStartDateChangedEvent>(_onStartDateChanged);
    on<OnboardingEndDateChangedEvent>(_onEndDateChanged);
    on<OnboardingSubmittedEvent>(_onSubmitted);
  }

  void _onInit(OnboardingInitEvent event, Emitter<OnboardingState> emit) {
    final now = DateTime.now();
    emit(
      state.copyWith(
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        selectedCurrency: _detectCurrency(event.localeCountryCode),
      ),
    );
  }

  CurrencyItem _detectCurrency(String? localeCountryCode) {
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
    final input = event.budgetInput.trim();
    if (input.isEmpty) {
      emit(
        state.copyWith(
          monthlyBudgetInput: input,
          clearParsedBudget: true,
          budgetValidationError: 'Budget amount cannot be empty',
        ),
      );
      return;
    }

    final doubleValue = double.tryParse(input);
    if (doubleValue == null) {
      emit(
        state.copyWith(
          monthlyBudgetInput: input,
          clearParsedBudget: true,
          budgetValidationError: 'Please enter a valid number',
        ),
      );
      return;
    }

    if (doubleValue <= 0) {
      emit(
        state.copyWith(
          monthlyBudgetInput: input,
          clearParsedBudget: true,
          budgetValidationError: 'Budget must be greater than zero',
        ),
      );
      return;
    }

    final decimalParts = input.split('.');
    if (decimalParts.length > 1 && decimalParts[1].length > 2) {
      emit(
        state.copyWith(
          monthlyBudgetInput: input,
          clearParsedBudget: true,
          budgetValidationError:
              'Budget cannot have more than 2 decimal places',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        monthlyBudgetInput: input,
        parsedBudget: doubleValue,
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
      orElse: () => CurrencyItem(
        code: event.code,
        symbol: event.symbol,
        name: event.code,
      ),
    );
    emit(state.copyWith(selectedCurrency: found));
  }

  void _onStartDateChanged(
    OnboardingStartDateChangedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    final newStart = event.date;
    final newEnd = state.endDate.isAfter(newStart)
        ? state.endDate
        : newStart.add(const Duration(days: 1));
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
    final newEnd = event.date;
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

    emit(state.copyWith(status: OnboardingStatus.loading, errorMessage: null));

    try {
      final now = DateTime.now();
      final budgetEntity = BudgetEntity(
        id: const Uuid().v4(),
        name: state.budgetNameInput.trim(),
        monthlyAmount: state.parsedBudget!,
        remainingAmount: state.parsedBudget!,
        currency: state.selectedCurrency.code,
        startDate: state.startDate,
        endDate: state.endDate,
        createdAt: now,
        updatedAt: now,
      );

      await createBudgetUseCase(budgetEntity);
      // Set the newly created budget as the active budget.
      await budgetRepository.setActiveBudgetId(budgetEntity.id);

      emit(state.copyWith(status: OnboardingStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: OnboardingStatus.failure,
          errorMessage: 'Failed to create initial budget: ${e.toString()}',
        ),
      );
    }
  }
}
