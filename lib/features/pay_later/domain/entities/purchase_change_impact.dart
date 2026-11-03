import 'package:equatable/equatable.dart';

import '../../../expenses/domain/entities/expense_entity.dart';
import 'payment_allocation.dart';

/// What a deleted tab purchase was linked to, so Undo can put it back on
/// its tab with the payment money it had.
class TabLinkSnapshot extends Equatable {
  final String tabId;

  /// The purchase's allocations at the moment it was deleted.
  final List<PaymentAllocation> allocations;

  const TabLinkSnapshot({required this.tabId, required this.allocations});

  @override
  List<Object?> get props => [tabId, allocations];
}

/// What an edit or delete of a tab purchase would do to payment money
/// already applied to it (spec §5, "Never silent"). A dry run: nothing is
/// written to produce it.
class PurchaseChangeImpact extends Equatable {
  /// Money already applied to this purchase that the change takes off it:
  /// all of it for a delete, a move to another tab or turning Pay later
  /// off; the part above the new amount for a lower amount; zero when the
  /// change leaves the payments alone (e.g. a higher amount).
  final double paidOnIt;

  /// Everything applied to this purchase before the change. Above
  /// [paidOnIt] when a lower amount keeps part of it paid; the same
  /// otherwise (the default).
  final double paidBefore;

  /// Other purchases on the tab that would receive the freed money, oldest
  /// first, with how much each one receives.
  final List<(ExpenseEntity, double)> movesTo;

  /// Freed money that nothing on the tab owes; it stays as tab credit.
  final double becomesCredit;

  /// The tab's currency; every amount above is in it.
  final String currency;

  const PurchaseChangeImpact({
    required this.paidOnIt,
    double? paidBefore,
    required this.movesTo,
    required this.becomesCredit,
    required this.currency,
  }) : paidBefore = paidBefore ?? paidOnIt;

  /// The change takes payment money off this purchase, so the user must be
  /// told where it goes before saving.
  bool get touchesPayments => paidOnIt > 0;

  @override
  List<Object?> get props => [
    paidOnIt,
    paidBefore,
    movesTo,
    becomesCredit,
    currency,
  ];
}
