import 'package:equatable/equatable.dart';

/// Immutable filter model for the expense history screen.
///
/// All fields are optional; combining multiple filters is supported.
class ExpenseHistoryFilter extends Equatable {
  /// Category id to filter by.
  final String? categoryId;

  /// Inclusive start of the date range (date part used).
  final DateTime? dateFrom;

  /// Inclusive end of the date range (date part used).
  final DateTime? dateTo;

  /// Minimum expense amount (inclusive).
  final double? minAmount;

  /// Maximum expense amount (inclusive).
  final double? maxAmount;

  /// Tags that must all be present on the expense.
  final List<String> tags;

  /// When true, only expenses with an attached receipt are shown.
  final bool receiptOnly;

  const ExpenseHistoryFilter({
    this.categoryId,
    this.dateFrom,
    this.dateTo,
    this.minAmount,
    this.maxAmount,
    this.tags = const [],
    this.receiptOnly = false,
  });

  bool get isActive =>
      categoryId != null ||
      dateFrom != null ||
      dateTo != null ||
      minAmount != null ||
      maxAmount != null ||
      tags.isNotEmpty ||
      receiptOnly;

  ExpenseHistoryFilter copyWithCategory(String? categoryId) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags,
      receiptOnly: receiptOnly,
    );
  }

  ExpenseHistoryFilter copyWithDateFrom(DateTime? dateFrom) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags,
      receiptOnly: receiptOnly,
    );
  }

  ExpenseHistoryFilter copyWithDateTo(DateTime? dateTo) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags,
      receiptOnly: receiptOnly,
    );
  }

  ExpenseHistoryFilter copyWithDateRange({
    required DateTime? from,
    required DateTime? to,
  }) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: from,
      dateTo: to,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags,
      receiptOnly: receiptOnly,
    );
  }

  ExpenseHistoryFilter copyWithMinAmount(double? minAmount) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags,
      receiptOnly: receiptOnly,
    );
  }

  ExpenseHistoryFilter copyWithMaxAmount(double? maxAmount) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags,
      receiptOnly: receiptOnly,
    );
  }

  ExpenseHistoryFilter copyWithoutTag(String tag) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags.where((t) => t != tag).toList(),
      receiptOnly: receiptOnly,
    );
  }

  ExpenseHistoryFilter copyWithReceiptOnly(bool receiptOnly) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags,
      receiptOnly: receiptOnly,
    );
  }

  @override
  List<Object?> get props => [
    categoryId,
    dateFrom,
    dateTo,
    minAmount,
    maxAmount,
    tags,
    receiptOnly,
  ];
}
