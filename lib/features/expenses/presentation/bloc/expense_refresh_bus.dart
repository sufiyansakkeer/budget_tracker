import 'dart:async';

/// Lightweight in-memory event bus that notifies dependent BLoCs
/// (Budget and Dashboard) to refresh after expense CRUD operations.
///
/// This avoids tight coupling between the expense module and the budget
/// engine while ensuring every expense change triggers a recalculation.
class ExpenseRefreshBus {
  ExpenseRefreshBus._();

  static final ExpenseRefreshBus instance = ExpenseRefreshBus._();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  /// Stream that emits whenever an expense was created, updated, or deleted.
  Stream<void> get changes => _controller.stream;

  /// Notifies listeners that expense data has changed.
  void notifyChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  void dispose() {
    _controller.close();
  }
}
