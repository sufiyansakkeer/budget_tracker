import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../pay_later/domain/entities/purchase_change_impact.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';

/// "Expense deleted · Undo" for a screen that closes as it deletes.
///
/// The screen's own [ExpenseBloc] is gone by the time Undo is tapped, so
/// the restore runs on a short-lived bloc that closes itself once the
/// expense is back (or the attempt failed). It re-creates the same expense
/// with the same id, exactly as Undo in the list does.
abstract final class ExpenseUndo {
  /// Builds the bloc a restore runs on; replaced in tests.
  @visibleForTesting
  static ExpenseBloc Function() blocFactory = () => getIt<ExpenseBloc>();

  /// [link]: the Pay later tab link the delete removed, so Undo puts the
  /// purchase back on its tab.
  static void offer(
    ScaffoldMessengerState messenger,
    ExpenseEntity deleted, {
    TabLinkSnapshot? link,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar(onUndo: () => restore(deleted, link: link)));
  }

  /// The "deleted · Undo" SnackBar every delete shows, held longer than a
  /// plain message so there is time to tap Undo.
  static SnackBar snackBar({
    String message = 'Expense deleted',
    required VoidCallback onUndo,
  }) => SnackBar(
    key: const Key('undoDeleteSnackBar'),
    content: Text(message),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(
      key: const Key('undoDeleteAction'),
      label: 'Undo',
      onPressed: onUndo,
    ),
  );

  /// Puts [expense] back and reports when that has finished.
  static Future<void> restore(
    ExpenseEntity expense, {
    TabLinkSnapshot? link,
  }) async {
    final bloc = blocFactory();
    final done = bloc.stream.firstWhere(
      (s) =>
          s.status == ExpenseBlocStatus.success ||
          s.status == ExpenseBlocStatus.error,
    );
    bloc.add(ExpenseRestore(expense, link: link));
    try {
      await done.timeout(const Duration(seconds: 10));
    } catch (e) {
      // The restore reports its own failure; only the bloc needs closing.
      debugPrint('[error] Waiting for an expense to be restored: $e');
    }
    await bloc.close();
  }
}
