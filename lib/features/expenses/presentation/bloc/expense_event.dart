import 'package:equatable/equatable.dart';

import '../../../pay_later/domain/entities/purchase_change_impact.dart';
import '../../domain/entities/expense_entity.dart';

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();

  @override
  List<Object?> get props => [];
}

/// Loads categories when the form screen opens.
class ExpenseLoadCategories extends ExpenseEvent {
  const ExpenseLoadCategories();
}

/// Initializes the Add Expense form's default date/time (captured once from
/// the device clock). The values are stored in the BLoC state so the form can
/// display pre-filled defaults that the user may still edit.
class ExpenseInitialize extends ExpenseEvent {
  const ExpenseInitialize();
}

/// Loads what the quick-add sheet needs: the active budget, the categories
/// and the most used ones over the last [days] days (all budgets).
class ExpenseLoadQuickAdd extends ExpenseEvent {
  final int days;

  /// "Now" for the look-back window; defaults to the device clock.
  final DateTime? now;

  const ExpenseLoadQuickAdd({this.days = 90, this.now});

  @override
  List<Object?> get props => [days, now];
}

/// Loads a single expense by id (for edit/details).
class ExpenseLoadById extends ExpenseEvent {
  final String id;

  const ExpenseLoadById(this.id);

  @override
  List<Object?> get props => [id];
}

/// Creates a new expense.
class ExpenseCreate extends ExpenseEvent {
  final ExpenseEntity expense;

  /// The Pay later tab the expense goes on; null ("Now") saves it exactly
  /// as before, with no Pay later read or write.
  final String? tabId;

  const ExpenseCreate(this.expense, {this.tabId});

  @override
  List<Object?> get props => [expense, tabId];
}

/// Updates an existing expense.
class ExpenseUpdate extends ExpenseEvent {
  final ExpenseEntity expense;

  /// The Pay later tab the expense is on after the edit (null: none).
  final String? tabId;

  /// The expense was on a tab before the edit, so a null [tabId] takes it
  /// off that tab. With neither, the edit saves exactly as before.
  final bool wasOnTab;

  const ExpenseUpdate(this.expense, {this.tabId, this.wasOnTab = false});

  @override
  List<Object?> get props => [expense, tabId, wasOnTab];
}

/// Deletes an expense by id.
class ExpenseDelete extends ExpenseEvent {
  final String id;

  /// False when the user already confirmed the delete (a tab purchase with
  /// payment money on it): no "Undo" is offered afterwards.
  final bool undoable;

  const ExpenseDelete(this.id, {this.undoable = true});

  @override
  List<Object?> get props => [id, undoable];
}

/// Re-creates an expense that was just deleted (SnackBar "Undo").
class ExpenseRestore extends ExpenseEvent {
  final ExpenseEntity expense;

  /// The tab link the delete removed, so the purchase comes back on its tab
  /// with its payment money; null for an expense that was on no tab.
  final TabLinkSnapshot? link;

  const ExpenseRestore(this.expense, {this.link});

  @override
  List<Object?> get props => [expense, link];
}

/// Clears transient messages (e.g. after a snackbar is shown).
class ExpenseClearMessage extends ExpenseEvent {
  const ExpenseClearMessage();
}
