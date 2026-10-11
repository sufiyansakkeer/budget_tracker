import 'package:equatable/equatable.dart';

/// What an import did, counted honestly: what was added or updated, and
/// what was skipped and why. Settings words its message from this, so a
/// re-import that adds nothing is never reported as a success.
class ImportReport extends Equatable {
  /// Expenses added.
  final int imported;

  /// Expenses already on this device that a data file (JSON) updated.
  final int updated;

  /// Rows skipped because the same expense is already on this device (its
  /// id matched), or appeared earlier in the same file.
  final int duplicates;

  /// Rows skipped because their amount or date could not be read.
  final int unreadable;

  /// Rows skipped because their currency differs from the budget they
  /// belong to, or no budget uses it. Amounts are never moved into another
  /// currency.
  final int otherCurrency;

  const ImportReport({
    this.imported = 0,
    this.updated = 0,
    this.duplicates = 0,
    this.unreadable = 0,
    this.otherCurrency = 0,
  });

  /// Rows that were not written.
  int get skipped => duplicates + unreadable + otherCurrency;

  @override
  List<Object?> get props => [
    imported,
    updated,
    duplicates,
    unreadable,
    otherCurrency,
  ];
}
