import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../domain/entities/purchase_change_impact.dart';

/// Asked before an edit or delete takes payment money off a purchase on a
/// tab (spec §5, "Never silent"): it says where that money goes.
abstract final class PurchaseImpactDialog {
  /// Shown when an edit of a purchase known to be on a tab can't check its
  /// payments; the change is not made.
  static const checkFailed =
      "Couldn't check this purchase's payments. Try again.";

  /// Shown when a delete can't read whether the expense is on a tab. The
  /// delete is not made, and the copy assumes no tab: most expenses are
  /// on none.
  static const deleteCheckFailed = "Couldn't delete the expense. Try again.";

  /// Shown when saving an edit can't read whether the expense is on a tab;
  /// nothing is saved. Neutral for the same reason.
  static const saveCheckFailed = "Couldn't save your changes. Try again.";

  /// True when the user goes ahead.
  static Future<bool> show(
    BuildContext context, {
    required PurchaseChangeImpact impact,
    required bool deleting,
  }) {
    return ConfirmationDialog.show(
      context: context,
      title: deleting ? 'Delete this purchase?' : 'Save this change?',
      message: message(impact, deleting: deleting),
      confirmLabel: deleting ? 'Delete' : 'Save',
      cancelLabel: 'Cancel',
      icon: deleting ? Icons.delete_outline_rounded : Icons.payments_outlined,
      isDestructive: deleting,
    );
  }

  /// E.g. "OMR 2.000 already paid on this purchase will go towards "Lunch"
  /// on 3 Nov." or "… will stay on the tab as credit." When a lower amount
  /// keeps part of it paid: "OMR 2.000 already paid on this purchase: OMR
  /// 1.000 stays paid, and OMR 1.000 will go towards …".
  @visibleForTesting
  static String message(PurchaseChangeImpact impact, {required bool deleting}) {
    final math = MoneyMath.forCurrency(impact.currency);
    String money(double amount) =>
        CurrencyFormatter.format(amount, code: impact.currency);
    final freedUnits = math.toUnits(impact.paidOnIt);
    final staysUnits = math.toUnits(impact.paidBefore) - freedUnits;
    final keepsPart = staysUnits > 0;
    final paid =
        '${money(keepsPart ? impact.paidBefore : impact.paidOnIt)} already '
        'paid on this purchase';
    final moves = impact.movesTo;
    final keepsCredit = impact.becomesCredit > 0;
    final moved = math.toAmount(math.sumUnits([for (final m in moves) m.$2]));
    final towards = moves.isEmpty ? '' : _targets(moves);
    const credit = 'will stay on the tab as credit';

    final String outcome;
    if (keepsPart) {
      // Each part is named: what stays, what moves, what becomes credit.
      final stays = '${money(math.toAmount(staysUnits))} stays paid';
      if (moves.isEmpty) {
        outcome = '$paid: $stays, and ${money(impact.paidOnIt)} $credit.';
      } else if (!keepsCredit) {
        outcome =
            '$paid: $stays, and ${money(impact.paidOnIt)} will go towards '
            '$towards.';
      } else {
        outcome =
            '$paid: $stays, ${money(moved)} will go towards $towards, and '
            '${money(impact.becomesCredit)} $credit.';
      }
    } else if (moves.isEmpty) {
      outcome = '$paid $credit.';
    } else if (!keepsCredit) {
      outcome = '$paid will go towards $towards.';
    } else {
      outcome =
          '$paid: ${money(moved)} will go towards $towards, and '
          '${money(impact.becomesCredit)} $credit.';
    }
    return deleting ? "$outcome You can't undo this." : outcome;
  }

  /// The purchases money goes towards. Purchases that would read the same
  /// (same day, same note) share one label ("your 2 Nov purchases"), so a
  /// label never repeats.
  static String _targets(List<(ExpenseEntity, double)> moves) {
    final groups = <String, List<ExpenseEntity>>{};
    for (final (purchase, _) in moves) {
      final day = DateFormat('d MMM').format(purchase.date);
      final note = purchase.note?.trim() ?? '';
      groups.putIfAbsent('$day\u0000$note', () => []).add(purchase);
    }
    final labels = [for (final group in groups.values) _describe(group)];
    final firstCount = groups.values.first.length;
    return switch (labels.length) {
      1 => labels.first,
      2 => '${labels.first} and ${labels[1]}',
      _ => '${labels.first} and ${moves.length - firstCount} other purchases',
    };
  }

  /// One label for purchases with the same day and note.
  static String _describe(List<ExpenseEntity> same) {
    final purchase = same.first;
    final day = DateFormat('d MMM').format(purchase.date);
    final note = purchase.note?.trim();
    final several = same.length > 1;
    if (note == null || note.isEmpty) {
      return several ? 'your $day purchases' : 'your $day purchase';
    }
    return several ? 'your "$note" purchases on $day' : '"$note" on $day';
  }
}
