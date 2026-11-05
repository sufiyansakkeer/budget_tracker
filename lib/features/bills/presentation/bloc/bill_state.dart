import 'package:equatable/equatable.dart';

import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../../domain/entities/bill_snapshot.dart';

enum BillBlocStatus {
  initial,
  loading,
  loaded,
  creating,
  updating,
  deleting,
  success,
  error,
}

/// What Undo takes back after a bill change: the bill as it was before
/// ([before]) and the expense the change recorded, if any.
class BillUndo extends Equatable {
  final BillSnapshot before;

  /// The expense "Pay & record" added, deleted by the undo.
  final String? recordedExpenseId;

  /// The change was a delete (Undo brings the bill back) rather than a
  /// payment.
  final bool deleted;

  const BillUndo({
    required this.before,
    this.recordedExpenseId,
    this.deleted = false,
  });

  @override
  List<Object?> get props => [before, recordedExpenseId, deleted];
}

class BillState extends Equatable {
  final BillBlocStatus status;
  final List<BillEntity> allBills;
  final BillEntity? selectedBill;
  final BillFilter filter;
  final String searchQuery;
  final String? message;

  /// What Undo puts back after the last success (mark paid, pay & record,
  /// delete). Transient: [copyWith] drops it unless given.
  final BillUndo? undo;

  const BillState({
    this.status = BillBlocStatus.initial,
    this.allBills = const [],
    this.selectedBill,
    this.filter = BillFilter.all,
    this.searchQuery = '',
    this.message,
    this.undo,
  });

  /// Unpaid bills due within this many days (today included) are "Due
  /// soon" in the list; later ones are "Later".
  static const int dueSoonDays = 7;

  /// Whether an unpaid, not-overdue [bill] is due within [dueSoonDays] of
  /// [now]'s calendar day.
  static bool isDueSoon(BillEntity bill, DateTime now) {
    if (bill.isPaid || bill.status == BillStatus.overdue) return false;
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      bill.dueDate.year,
      bill.dueDate.month,
      bill.dueDate.day,
    );
    return due.isBefore(
      DateTime(today.year, today.month, today.day + dueSoonDays),
    );
  }

  /// Unpaid, not overdue and due after the [dueSoonDays] window.
  static bool isLater(BillEntity bill, DateTime now) =>
      !bill.isPaid &&
      bill.status != BillStatus.overdue &&
      !isDueSoon(bill, now);

  bool get isBusy =>
      status == BillBlocStatus.creating ||
      status == BillBlocStatus.updating ||
      status == BillBlocStatus.deleting;

  /// Bills filtered by active filter and search query.
  List<BillEntity> get filteredBills {
    var result = List<BillEntity>.of(allBills);

    // Apply filter: the same groups as the list's sections.
    final now = DateTime.now();
    switch (filter) {
      case BillFilter.all:
        break;
      case BillFilter.dueSoon:
        result = result.where((b) => isDueSoon(b, now)).toList();
        break;
      case BillFilter.later:
        result = result.where((b) => isLater(b, now)).toList();
        break;
      case BillFilter.overdue:
        result = result.where((b) => b.status == BillStatus.overdue).toList();
        break;
      case BillFilter.paid:
        result = result.where((b) => b.status == BillStatus.paid).toList();
        break;
      case BillFilter.recurring:
        result = result.where((b) => b.repeats).toList();
        break;
      case BillFilter.notLinked:
        result = result.where((b) => b.budgetId == null).toList();
        break;
    }

    // Apply search.
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((b) {
        return b.title.toLowerCase().contains(query) ||
            b.category.label.toLowerCase().contains(query) ||
            (b.note != null && b.note!.toLowerCase().contains(query));
      }).toList();
    }

    // Sort: overdue first, then due today, then by due date ascending.
    result.sort((a, b) {
      // Paid bills go to the bottom.
      if (a.isPaid && !b.isPaid) return 1;
      if (!a.isPaid && b.isPaid) return -1;

      // Among unpaid bills: overdue > due today > upcoming by due date.
      final statusOrder = {
        BillStatus.overdue: 0,
        BillStatus.dueToday: 1,
        BillStatus.upcoming: 2,
        BillStatus.paid: 3,
      };
      final cmp = (statusOrder[a.status] ?? 2).compareTo(
        statusOrder[b.status] ?? 2,
      );
      if (cmp != 0) return cmp;
      return a.dueDate.compareTo(b.dueDate);
    });

    return result;
  }

  BillState copyWith({
    BillBlocStatus? status,
    List<BillEntity>? allBills,
    BillEntity? selectedBill,
    BillFilter? filter,
    String? searchQuery,
    String? message,
    bool clearMessage = false,
    BillUndo? undo,
  }) {
    return BillState(
      status: status ?? this.status,
      allBills: allBills ?? this.allBills,
      selectedBill: selectedBill ?? this.selectedBill,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      message: clearMessage ? null : (message ?? this.message),
      undo: undo,
    );
  }

  @override
  List<Object?> get props => [
    status,
    allBills,
    selectedBill,
    filter,
    searchQuery,
    message,
    undo,
  ];
}
