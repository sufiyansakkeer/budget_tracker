import 'package:equatable/equatable.dart';

abstract class CurrencyConverterEvent extends Equatable {
  const CurrencyConverterEvent();

  @override
  List<Object?> get props => [];
}

/// Restores the last pair and amount, loads the currency list and the rate.
/// Dispatched once, when the converter route creates its BLoC.
class CurrencyConverterStarted extends CurrencyConverterEvent {
  const CurrencyConverterStarted();
}

class CurrencyConverterSourceSelected extends CurrencyConverterEvent {
  final String code;

  const CurrencyConverterSourceSelected(this.code);

  @override
  List<Object?> get props => [code];
}

class CurrencyConverterTargetSelected extends CurrencyConverterEvent {
  final String code;

  const CurrencyConverterTargetSelected(this.code);

  @override
  List<Object?> get props => [code];
}

/// The amount field changed. Converts locally with the loaded rate; never
/// touches the network.
class CurrencyConverterAmountChanged extends CurrencyConverterEvent {
  final String text;

  const CurrencyConverterAmountChanged(this.text);

  @override
  List<Object?> get props => [text];
}

/// Swaps source and target, keeping the amount.
class CurrencyConverterSwapped extends CurrencyConverterEvent {
  const CurrencyConverterSwapped();
}

/// The user tapped "Refresh rate": ask the provider even if the cached rate
/// is still fresh.
class CurrencyConverterRateRefreshed extends CurrencyConverterEvent {
  const CurrencyConverterRateRefreshed();
}

/// Retry after a failed lookup (no cached rate was available).
class CurrencyConverterRetried extends CurrencyConverterEvent {
  const CurrencyConverterRetried();
}

class CurrencyConverterNoticeCleared extends CurrencyConverterEvent {
  const CurrencyConverterNoticeCleared();
}
