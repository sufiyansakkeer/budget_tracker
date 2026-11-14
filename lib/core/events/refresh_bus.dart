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

/// Runs an action once for a burst of bus events. Paying a bill notifies
/// the bills and expenses buses back to back, and an import or restore
/// notifies three, but a listener only needs to re-read once.
///
/// The burst is everything notified in the same synchronous run: the
/// action waits for a microtask, after the buses have delivered.
class RefreshCoalescer {
  final void Function() _action;
  bool _queued = false;

  RefreshCoalescer(this._action);

  /// Asks for the action; calls before it runs are folded into one.
  void call() {
    if (_queued) return;
    _queued = true;
    scheduleMicrotask(() {
      _queued = false;
      _action();
    });
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

  /// Pay Later tab, purchase link or payment created, changed or removed.
  static final RefreshBus payLater = RefreshBus('payLater');

  /// The calendar day changed while the app stayed alive (seen on resume or
  /// at midnight), so every "today" figure must be worked out again.
  /// Notified by `DayChangeWatcher`.
  static final RefreshBus day = RefreshBus('day');
}
