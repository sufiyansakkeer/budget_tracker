import 'package:equatable/equatable.dart';

import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';

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

class BillState extends Equatable {
  final BillBlocStatus status;
  final List<BillEntity> allBills;
  final BillEntity? selectedBill;
  final BillFilter filter;
  final String searchQuery;
  final String? message;

  const BillState({
    this.status = BillBlocStatus.initial,
    this.allBills = const [],
    this.selectedBill,
    this.filter = BillFilter.all,
    this.searchQuery = '',
    this.message,
  });

  bool get isBusy =>
      status == BillBlocStatus.creating ||
      status == BillBlocStatus.updating ||
      status == BillBlocStatus.deleting;

  /// Bills filtered by active filter and search query.
  List<BillEntity> get filteredBills {
    var result = List<BillEntity>.of(allBills);

    // Apply filter.
    switch (filter) {
      case BillFilter.all:
        break;
      case BillFilter.upcoming:
        result = result.where((b) => b.status == BillStatus.upcoming).toList();
        break;
      case BillFilter.dueToday:
        result = result.where((b) => b.status == BillStatus.dueToday).toList();
        break;
      case BillFilter.overdue:
        result = result.where((b) => b.status == BillStatus.overdue).toList();
        break;
      case BillFilter.paid:
        result = result.where((b) => b.status == BillStatus.paid).toList();
        break;
      case BillFilter.recurring:
        result = result.where((b) => b.isRecurring).toList();
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

  /// Bills with status == upcoming.
  List<BillEntity> get upcomingBills =>
      allBills.where((b) => b.status == BillStatus.upcoming).toList();

  /// Bills with status == dueToday.
  List<BillEntity> get dueTodayBills =>
      allBills.where((b) => b.status == BillStatus.dueToday).toList();

  /// Bills with status == overdue.
  List<BillEntity> get overdueBills =>
      allBills.where((b) => b.status == BillStatus.overdue).toList();

  /// Bills with status == paid.
  List<BillEntity> get paidBills =>
      allBills.where((b) => b.status == BillStatus.paid).toList();

  /// Total amount of upcoming bills (due today + upcoming).
  double get upcomingTotal {
    double total = 0;
    for (final bill in allBills) {
      if (!bill.isPaid &&
          (bill.status == BillStatus.upcoming ||
              bill.status == BillStatus.dueToday)) {
        total += bill.amount;
      }
    }
    return total;
  }

  /// Total amount of overdue bills.
  double get overdueTotal {
    double total = 0;
    for (final bill in overdueBills) {
      total += bill.amount;
    }
    return total;
  }

  /// Total amount of due today bills.
  double get dueTodayTotal {
    double total = 0;
    for (final bill in dueTodayBills) {
      total += bill.amount;
    }
    return total;
  }

  BillState copyWith({
    BillBlocStatus? status,
    List<BillEntity>? allBills,
    BillEntity? selectedBill,
    bool clearSelectedBill = false,
    BillFilter? filter,
    String? searchQuery,
    String? message,
    bool clearMessage = false,
  }) {
    return BillState(
      status: status ?? this.status,
      allBills: allBills ?? this.allBills,
      selectedBill: clearSelectedBill
          ? null
          : (selectedBill ?? this.selectedBill),
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      message: clearMessage ? null : (message ?? this.message),
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
  ];
}
