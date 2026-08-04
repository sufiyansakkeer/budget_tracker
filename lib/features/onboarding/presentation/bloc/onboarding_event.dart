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

class OnboardingSubmittedEvent extends OnboardingEvent {
  const OnboardingSubmittedEvent();
}
