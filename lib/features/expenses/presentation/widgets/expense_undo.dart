import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../pay_later/domain/entities/purchase_change_impact.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';

/// "Expense deleted · Undo" for a screen that closes as it deletes, and
/// "₹250 added · Undo" for one that closes as it adds.
///
/// The screen's own [ExpenseBloc] is gone by the time Undo is tapped, so
/// the undo runs on a short-lived bloc that closes itself once it has
/// finished (or the attempt failed). A delete is undone by re-creating the
/// same expense with the same id, exactly as Undo in the list does; an add
/// by deleting the expense it created.
abstract final class ExpenseUndo {
  /// Builds the bloc a restore runs on; replaced in tests.
  @visibleForTesting
  static ExpenseBloc Function() blocFactory = () => getIt<ExpenseBloc>();

  /// [link]: the Pay later tab link the delete removed, so Undo puts the
  /// purchase back on its tab. Once Undo has run, [messenger] says
  /// "Expense restored" or why it couldn't be, as the list does.
  static void offer(
    ScaffoldMessengerState messenger,
    ExpenseEntity deleted, {
    TabLinkSnapshot? link,
  }) {
    AppSnack.present(
      messenger,
      snackBar(
        onUndo: () => restore(deleted, link: link, messenger: messenger),
      ),
    );
  }

  /// The "deleted · Undo" SnackBar every delete shows; [AppSnack] holds
  /// it longer than a plain message so there is time to tap Undo.
  static SnackBar snackBar({
    String message = 'Expense deleted',
    required VoidCallback onUndo,
  }) => AppSnack.bar(
    message,
    key: const Key('undoDeleteSnackBar'),
    actionKey: const Key('undoDeleteAction'),
    actionLabel: 'Undo',
    onAction: onUndo,
  );

  /// "₹250 added · ₹627 left today" after [added] was saved, with Undo.
  /// [after] is the budget's Today's Safe Spending once it is counted
  /// (`ExpenseState.afterAdd`); without it the note gives the amount only.
  static void offerAdded(
    ScaffoldMessengerState messenger,
    ExpenseEntity added, {
    required String? currency,
    SafeToSpendEntity? after,
  }) {
    AppSnack.present(
      messenger,
      snackBar(
        message: _addedMessage(added, currency: currency, after: after),
        onUndo: () => remove(added.id),
      ),
    );
  }

  static String _addedMessage(
    ExpenseEntity added, {
    required String? currency,
    SafeToSpendEntity? after,
  }) {
    final amount = AppMoney.format(added.amount, currency: currency);
    if (after == null) return '$amount added';
    return after.overToday > 0
        ? '$amount added · over by '
              '${AppMoney.format(after.overToday, currency: after.currency)} '
              'today'
        : '$amount added · '
              '${AppMoney.format(after.remainingToday, currency: after.currency, floored: true)} '
              'left today';
  }

  /// "Moved to Home · Undo" after [original] was moved to [to], the same
  /// from the list and from its details; [onUndone] runs once it is back.
  /// A bill payment offers no Undo: the move unlinked it from its bill, and
  /// moving it back can't link it again.
  static void offerMoved(
    ScaffoldMessengerState messenger,
    ExpenseEntity original, {
    required String to,
    VoidCallback? onUndone,
  }) {
    final message = 'Moved to $to';
    AppSnack.present(
      messenger,
      original.billId != null
          ? AppSnack.bar(message)
          : snackBar(
              message: message,
              onUndo: () => _run(
                ExpenseUpdate(original.copyWith(updatedAt: DateTime.now())),
                onDone: onUndone,
              ),
            ),
    );
  }

  /// Puts [expense] back and reports when that has finished; with
  /// [messenger], also on screen: "Expense restored", or the failure.
  static Future<void> restore(
    ExpenseEntity expense, {
    TabLinkSnapshot? link,
    ScaffoldMessengerState? messenger,
  }) => _run(
    ExpenseRestore(expense, link: link),
    onOutcome: (outcome) {
      if (messenger == null || outcome == null || !messenger.mounted) return;
      final restored = outcome.status == ExpenseBlocStatus.success;
      AppSnack.showOn(
        messenger,
        restored
            ? 'Expense restored'
            : outcome.message ?? "Couldn't restore the expense. Try again.",
      );
    },
  );

  /// Deletes the expense an add created (a purchase on a tab comes off it
  /// too), and reports when that has finished.
  static Future<void> remove(String id) =>
      _run(ExpenseDelete(id, undoable: false));

  /// [onDone] runs once the bloc has finished, before it closes;
  /// [onOutcome] too, with the state it finished in (success or error), or
  /// null when it didn't finish in time.
  static Future<void> _run(
    ExpenseEvent event, {
    VoidCallback? onDone,
    void Function(ExpenseState? outcome)? onOutcome,
  }) async {
    final bloc = blocFactory();
    final done = bloc.stream.firstWhere(
      (s) =>
          s.status == ExpenseBlocStatus.success ||
          s.status == ExpenseBlocStatus.error,
    );
    bloc.add(event);
    ExpenseState? outcome;
    try {
      outcome = await done.timeout(const Duration(seconds: 10));
    } catch (e) {
      // The bloc reports its own failure; only the bloc needs closing.
      debugPrint('[error] Waiting for an undo to finish: $e');
    }
    onDone?.call();
    onOutcome?.call(outcome);
    await bloc.close();
  }
}
