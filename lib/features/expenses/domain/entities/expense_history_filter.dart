import 'package:equatable/equatable.dart';

/// What kind of money event to show (blueprint: Activity's chips). A bill
/// payment is an expense with a bill id.
enum ExpenseKind {
  all('All'),
  expenses('Expenses'),
  bills('Bills'),
  payLater('Pay later'),
  budgets('Budgets');

  final String label;
  const ExpenseKind(this.label);
}

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

  /// Every expense, only plain expenses, or only bill payments.
  final ExpenseKind kind;

  const ExpenseHistoryFilter({
    this.categoryId,
    this.dateFrom,
    this.dateTo,
    this.minAmount,
    this.maxAmount,
    this.tags = const [],
    this.receiptOnly = false,
    this.kind = ExpenseKind.all,
  });

  bool get isActive =>
      categoryId != null ||
      dateFrom != null ||
      dateTo != null ||
      minAmount != null ||
      maxAmount != null ||
      tags.isNotEmpty ||
      receiptOnly ||
      kind != ExpenseKind.all;

  ExpenseHistoryFilter copyWithCategory(String? categoryId) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags,
      receiptOnly: receiptOnly,
      kind: kind,
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
      kind: kind,
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
      kind: kind,
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
      kind: kind,
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
      kind: kind,
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
      kind: kind,
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
      kind: kind,
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
      kind: kind,
    );
  }

  ExpenseHistoryFilter copyWithKind(ExpenseKind kind) {
    return ExpenseHistoryFilter(
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tags: tags,
      receiptOnly: receiptOnly,
      kind: kind,
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
    kind,
  ];
}
