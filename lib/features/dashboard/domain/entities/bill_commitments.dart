import 'package:equatable/equatable.dart';

import '../../../budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import '../../../budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import '../../../budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';

/// What the bills mean for one budget, built by `BillOccurrenceEnumerator`
/// and handed to the safe-to-spend engine as primitives.
class BillCommitments extends Equatable {
  /// Unpaid occurrences of bills linked to the budget, in its currency, that
  /// the budget sets money aside for.
  final List<CommitmentOccurrence> occurrences;

  /// Bills linked to the budget in another currency (left out, disclosed).
  final CurrencyExcludedSummary currencyExcluded;

  /// Bills in the budget's currency that no budget sets money aside for.
  final UnlinkedCommitmentSummary unlinked;

  const BillCommitments({
    required this.occurrences,
    this.currencyExcluded = CurrencyExcludedSummary.none,
    this.unlinked = UnlinkedCommitmentSummary.none,
  });

  static const empty = BillCommitments(occurrences: []);

  @override
  List<Object?> get props => [occurrences, currencyExcluded, unlinked];
}
