import 'package:equatable/equatable.dart';

sealed class TabDetailEvent extends Equatable {
  const TabDetailEvent();

  @override
  List<Object?> get props => const [];
}

/// First load of [tabId], or Try again after a failure: shows the loading
/// state.
class TabDetailStarted extends TabDetailEvent {
  final String tabId;

  const TabDetailStarted(this.tabId);

  @override
  List<Object?> get props => [tabId];
}

/// Something changed (a refresh bus fired): reloads behind what is shown.
class TabDetailRefreshed extends TabDetailEvent {
  const TabDetailRefreshed();
}

class TabDetailArchiveRequested extends TabDetailEvent {
  const TabDetailArchiveRequested();
}

class TabDetailUnarchiveRequested extends TabDetailEvent {
  const TabDetailUnarchiveRequested();
}

/// Deletes the tab (offered only when it has no purchases or payments).
class TabDetailDeleteRequested extends TabDetailEvent {
  const TabDetailDeleteRequested();
}

/// Deletes one payment (already confirmed by the user).
class TabDetailPaymentDeleteRequested extends TabDetailEvent {
  final String paymentId;

  const TabDetailPaymentDeleteRequested(this.paymentId);

  @override
  List<Object?> get props => [paymentId];
}
