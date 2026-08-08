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
  final String budgetNameInput;
  final String monthlyBudgetInput;
  final double? parsedBudget;
  final String? budgetValidationError;
  final String? nameValidationError;
  final String? dateValidationError;
  final CurrencyItem selectedCurrency;
  final DateTime startDate;
  final DateTime endDate;
  final OnboardingStatus status;
  final String? errorMessage;

  const OnboardingState({
    this.currentPageIndex = 0,
    this.budgetNameInput = '',
    this.monthlyBudgetInput = '',
    this.parsedBudget,
    this.budgetValidationError,
    this.nameValidationError,
    this.dateValidationError,
    this.selectedCurrency = const CurrencyItem(
      code: 'INR',
      symbol: '₹',
      name: 'Indian Rupee',
    ),
    required this.startDate,
    required this.endDate,
    this.status = OnboardingStatus.initial,
    this.errorMessage,
  });

  bool get isBudgetValid =>
      parsedBudget != null &&
      parsedBudget! > 0 &&
      budgetValidationError == null;

  bool get isNameValid =>
      budgetNameInput.trim().isNotEmpty && nameValidationError == null;

  bool get isDateRangeValid =>
      endDate.isAfter(startDate) && dateValidationError == null;

  bool get isAllValid => isBudgetValid && isNameValid && isDateRangeValid;

  OnboardingState copyWith({
    int? currentPageIndex,
    String? budgetNameInput,
    String? monthlyBudgetInput,
    double? parsedBudget,
    String? budgetValidationError,
    bool clearBudgetValidationError = false,
    String? nameValidationError,
    bool clearNameValidationError = false,
    String? dateValidationError,
    bool clearDateValidationError = false,
    CurrencyItem? selectedCurrency,
    DateTime? startDate,
    DateTime? endDate,
    OnboardingStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return OnboardingState(
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      budgetNameInput: budgetNameInput ?? this.budgetNameInput,
      monthlyBudgetInput: monthlyBudgetInput ?? this.monthlyBudgetInput,
      parsedBudget: parsedBudget ?? this.parsedBudget,
      budgetValidationError: clearBudgetValidationError
          ? null
          : (budgetValidationError ?? this.budgetValidationError),
      nameValidationError: clearNameValidationError
          ? null
          : (nameValidationError ?? this.nameValidationError),
      dateValidationError: clearDateValidationError
          ? null
          : (dateValidationError ?? this.dateValidationError),
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    currentPageIndex,
    budgetNameInput,
    monthlyBudgetInput,
    parsedBudget,
    budgetValidationError,
    nameValidationError,
    dateValidationError,
    selectedCurrency,
    startDate,
    endDate,
    status,
    errorMessage,
  ];
}
