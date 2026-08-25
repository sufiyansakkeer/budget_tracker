import 'dart:async';

/// A lightweight event bus that notifies listeners when bills change
/// (created, updated, deleted, paid, etc.).
///
/// Mirrors the existing [ExpenseRefreshBus] pattern used in the app.
class BillRefreshBus {
  BillRefreshBus._();

  static final BillRefreshBus instance = BillRefreshBus._();

  final _controller = StreamController<void>.broadcast();

  /// Stream that emits when any bill changes.
  Stream<void> get changes => _controller.stream;

  /// Notifies all listeners that a bill change occurred.
  void notifyChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  void dispose() {
    _controller.close();
  }
}
