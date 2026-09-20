import 'dart:async';

/// In-memory broadcast channel that tells dependent BLoCs and listeners
/// "this kind of data changed, reload".
///
/// Buses decouple features: the expense form does not know that the
/// dashboard, reports, budget list and home-screen widget all need to react
/// to a new expense; it simply notifies [RefreshBuses.expenses].
///
/// A bus carries no payload on purpose — consumers always re-read from the
/// repository so they can never act on stale data.
class RefreshBus {
  /// Human-readable name, useful in logs and tests.
  final String name;

  final StreamController<void> _controller = StreamController<void>.broadcast();

  RefreshBus(this.name);

  /// Emits every time [notifyChanged] is called.
  Stream<void> get changes => _controller.stream;

  /// Whether at least one listener is currently subscribed.
  bool get hasListeners => _controller.hasListener;

  /// Notifies every listener that the data behind this bus changed.
  void notifyChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  /// Closes the underlying stream. Only intended for tests; the app-wide
  /// buses in [RefreshBuses] live for the whole process.
  void dispose() {
    _controller.close();
  }
}

/// The app-wide buses. One instance per kind of data.
abstract final class RefreshBuses {
  /// Expense created, updated, deleted or restored.
  static final RefreshBus expenses = RefreshBus('expenses');

  /// Budget created, edited, archived, deleted or the active budget switched.
  static final RefreshBus budgets = RefreshBus('budgets');

  /// Bill created, edited, deleted, paid or unpaid.
  static final RefreshBus bills = RefreshBus('bills');
}
