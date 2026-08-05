import 'package:equatable/equatable.dart';

import '../entities/expense_entity.dart';

/// Result of a pagination slice.
class ExpensePage extends Equatable {
  final List<ExpenseEntity> items;
  final int offset;
  final bool hasMore;

  const ExpensePage({
    required this.items,
    required this.offset,
    required this.hasMore,
  });

  @override
  List<Object?> get props => [items, offset, hasMore];
}

/// Slices a sorted list of expenses into pages, enabling lazy loading.
///
/// The blocktype offset is the number of items already loaded. Pass
/// `offset >= items.length` to detect the end of the list.
class PageExpensesUseCase {
  final int pageSize;

  const PageExpensesUseCase({this.pageSize = 20});

  ExpensePage call({required int offset, required List<ExpenseEntity> items}) {
    if (offset >= items.length) {
      return ExpensePage(items: const [], offset: offset, hasMore: false);
    }

    final end = (offset + pageSize).clamp(0, items.length);
    final slice = items.sublist(offset, end);
    return ExpensePage(items: slice, offset: end, hasMore: end < items.length);
  }
}
