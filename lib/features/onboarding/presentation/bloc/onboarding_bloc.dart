import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
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

  OnboardingBloc({required this.createBudgetUseCase})
      : super(
          OnboardingState(
            month: DateTime.now().month,
            year: DateTime.now().year,
          ),
        ) {
    on<OnboardingInitEvent>(_onInit);
    on<OnboardingPageChangedEvent>(_onPageChanged);
    on<OnboardingBudgetInputChangedEvent>(_onBudgetInputChanged);
    on<OnboardingCurrencySelectedEvent>(_onCurrencySelected);
    on<OnboardingSubmittedEvent>(_onSubmitted);
  }

  void _onInit(OnboardingInitEvent event, Emitter<OnboardingState> emit) {
    final now = DateTime.now();
    CurrencyItem detectedCurrency = availableCurrencies.first;

    if (event.localeCountryCode != null) {
      final code = event.localeCountryCode!.toUpperCase();
      switch (code) {
        case 'IN':
          detectedCurrency = availableCurrencies.firstWhere((c) => c.code == 'INR');
          break;
        case 'US':
          detectedCurrency = availableCurrencies.firstWhere((c) => c.code == 'USD');
          break;
        case 'AE':
          detectedCurrency = availableCurrencies.firstWhere((c) => c.code == 'AED');
          break;
        case 'OM':
          detectedCurrency = availableCurrencies.firstWhere((c) => c.code == 'OMR');
          break;
        case 'GB':
          detectedCurrency = availableCurrencies.firstWhere((c) => c.code == 'GBP');
          break;
        case 'CA':
          detectedCurrency = availableCurrencies.firstWhere((c) => c.code == 'CAD');
          break;
        case 'AU':
          detectedCurrency = availableCurrencies.firstWhere((c) => c.code == 'AUD');
          break;
        case 'JP':
          detectedCurrency = availableCurrencies.firstWhere((c) => c.code == 'JPY');
          break;
        case 'SG':
          detectedCurrency = availableCurrencies.firstWhere((c) => c.code == 'SGD');
          break;
        default:
          break;
      }
    }

    emit(state.copyWith(
      month: now.month,
      year: now.year,
      selectedCurrency: detectedCurrency,
    ));
  }

  void _onPageChanged(OnboardingPageChangedEvent event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(currentPageIndex: event.pageIndex));
  }

  void _onBudgetInputChanged(OnboardingBudgetInputChangedEvent event, Emitter<OnboardingState> emit) {
    final input = event.budgetInput.trim();
    if (input.isEmpty) {
      emit(state.copyWith(
        monthlyBudgetInput: input,
        parsedBudget: null,
        budgetValidationError: 'Monthly budget cannot be empty',
      ));
      return;
    }

    final doubleValue = double.tryParse(input);
    if (doubleValue == null) {
      emit(state.copyWith(
        monthlyBudgetInput: input,
        parsedBudget: null,
        budgetValidationError: 'Please enter a valid number',
      ));
      return;
    }

    if (doubleValue <= 0) {
      emit(state.copyWith(
        monthlyBudgetInput: input,
        parsedBudget: null,
        budgetValidationError: 'Budget must be greater than zero',
      ));
      return;
    }

    final decimalParts = input.split('.');
    if (decimalParts.length > 1 && decimalParts[1].length > 2) {
      emit(state.copyWith(
        monthlyBudgetInput: input,
        parsedBudget: null,
        budgetValidationError: 'Budget cannot have more than 2 decimal places',
      ));
      return;
    }

    emit(state.copyWith(
      monthlyBudgetInput: input,
      parsedBudget: doubleValue,
      clearBudgetValidationError: true,
    ));
  }

  void _onCurrencySelected(OnboardingCurrencySelectedEvent event, Emitter<OnboardingState> emit) {
    final found = availableCurrencies.firstWhere(
      (c) => c.code == event.code,
      orElse: () => CurrencyItem(code: event.code, symbol: event.symbol, name: event.code),
    );
    emit(state.copyWith(selectedCurrency: found));
  }

  Future<void> _onSubmitted(OnboardingSubmittedEvent event, Emitter<OnboardingState> emit) async {
    if (!state.isBudgetValid) {
      emit(state.copyWith(
        status: OnboardingStatus.failure,
        errorMessage: state.budgetValidationError ?? 'Please provide a valid budget',
      ));
      return;
    }

    emit(state.copyWith(status: OnboardingStatus.loading, clearErrorMessage: true));

    try {
      final now = DateTime.now();
      final budgetEntity = BudgetEntity(
        id: const Uuid().v4(),
        monthlyAmount: state.parsedBudget!,
        remainingAmount: state.parsedBudget!,
        currency: state.selectedCurrency.code,
        month: state.month,
        year: state.year,
        createdAt: now,
      );

      await createBudgetUseCase(budgetEntity);

      emit(state.copyWith(status: OnboardingStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: OnboardingStatus.failure,
        errorMessage: 'Failed to create initial budget: ${e.toString()}',
      ));
    }
  }
}
