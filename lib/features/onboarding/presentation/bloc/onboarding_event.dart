import 'package:equatable/equatable.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

class OnboardingInitEvent extends OnboardingEvent {
  final String? localeCountryCode;

  const OnboardingInitEvent({this.localeCountryCode});

  @override
  List<Object?> get props => [localeCountryCode];
}

class OnboardingPageChangedEvent extends OnboardingEvent {
  final int pageIndex;

  const OnboardingPageChangedEvent(this.pageIndex);

  @override
  List<Object?> get props => [pageIndex];
}

class OnboardingBudgetNameChangedEvent extends OnboardingEvent {
  final String name;

  const OnboardingBudgetNameChangedEvent(this.name);

  @override
  List<Object?> get props => [name];
}

class OnboardingBudgetInputChangedEvent extends OnboardingEvent {
  final String budgetInput;

  const OnboardingBudgetInputChangedEvent(this.budgetInput);

  @override
  List<Object?> get props => [budgetInput];
}

class OnboardingCurrencySelectedEvent extends OnboardingEvent {
  final String code;
  final String symbol;

  const OnboardingCurrencySelectedEvent({
    required this.code,
    required this.symbol,
  });

  @override
  List<Object?> get props => [code, symbol];
}

class OnboardingStartDateChangedEvent extends OnboardingEvent {
  final DateTime date;

  const OnboardingStartDateChangedEvent(this.date);

  @override
  List<Object?> get props => [date];
}

class OnboardingEndDateChangedEvent extends OnboardingEvent {
  final DateTime date;

  const OnboardingEndDateChangedEvent(this.date);

  @override
  List<Object?> get props => [date];
}

class OnboardingSubmittedEvent extends OnboardingEvent {
  const OnboardingSubmittedEvent();
}
