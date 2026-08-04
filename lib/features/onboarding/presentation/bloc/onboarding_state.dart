import 'package:equatable/equatable.dart';

enum OnboardingStatus { initial, loading, success, failure }

class CurrencyItem extends Equatable {
  final String code;
  final String symbol;
  final String name;

  const CurrencyItem({
    required this.code,
    required this.symbol,
    required this.name,
  });

  @override
  List<Object?> get props => [code, symbol, name];
}

class OnboardingState extends Equatable {
  final int currentPageIndex;
  final String monthlyBudgetInput;
  final double? parsedBudget;
  final String? budgetValidationError;
  final CurrencyItem selectedCurrency;
  final int month;
  final int year;
  final OnboardingStatus status;
  final String? errorMessage;

  const OnboardingState({
    this.currentPageIndex = 0,
    this.monthlyBudgetInput = '',
    this.parsedBudget,
    this.budgetValidationError,
    this.selectedCurrency = const CurrencyItem(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    required this.month,
    required this.year,
    this.status = OnboardingStatus.initial,
    this.errorMessage,
  });

  bool get isBudgetValid => parsedBudget != null && parsedBudget! > 0 && budgetValidationError == null;

  OnboardingState copyWith({
    int? currentPageIndex,
    String? monthlyBudgetInput,
    double? parsedBudget,
    String? budgetValidationError,
    bool clearBudgetValidationError = false,
    CurrencyItem? selectedCurrency,
    int? month,
    int? year,
    OnboardingStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return OnboardingState(
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      monthlyBudgetInput: monthlyBudgetInput ?? this.monthlyBudgetInput,
      parsedBudget: parsedBudget ?? this.parsedBudget,
      budgetValidationError: clearBudgetValidationError ? null : (budgetValidationError ?? this.budgetValidationError),
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      month: month ?? this.month,
      year: year ?? this.year,
      status: status ?? this.status,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        currentPageIndex,
        monthlyBudgetInput,
        parsedBudget,
        budgetValidationError,
        selectedCurrency,
        month,
        year,
        status,
        errorMessage,
      ];
}
