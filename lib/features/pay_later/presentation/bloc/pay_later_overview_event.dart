import 'package:equatable/equatable.dart';

sealed class PayLaterOverviewEvent extends Equatable {
  const PayLaterOverviewEvent();

  @override
  List<Object?> get props => const [];
}

/// First load, or Try again after a failure: shows the loading state.
class PayLaterOverviewStarted extends PayLaterOverviewEvent {
  const PayLaterOverviewStarted();
}

/// Something changed elsewhere (a refresh bus fired): reloads behind what
/// is shown.
class PayLaterOverviewRefreshed extends PayLaterOverviewEvent {
  const PayLaterOverviewRefreshed();
}

/// The charts switch to [currency].
class PayLaterOverviewCurrencySelected extends PayLaterOverviewEvent {
  final String currency;

  const PayLaterOverviewCurrencySelected(this.currency);

  @override
  List<Object?> get props => [currency];
}
