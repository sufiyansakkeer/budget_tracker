import 'package:equatable/equatable.dart';

import '../../../expenses/domain/entities/expense_category.dart';
import '../../domain/entities/tab_ledger.dart';

enum TabDetailStatus { initial, loading, loaded, notFound, error }

class TabDetailState extends Equatable {
  final TabDetailStatus status;
  final TabLedger? ledger;

  /// Expense categories by id, for naming purchases and the breakdown.
  /// Empty when they couldn't be read (names fall back).
  final Map<String, ExpenseCategory> categories;

  /// Expense category id → Σ this tab's purchases in it; null while loading
  /// or when it couldn't be worked out (the section is left out).
  final Map<String, double>? byCategory;

  /// What a failed first load says.
  final String? errorMessage;

  /// An archive, unarchive, delete or payment delete is running.
  final bool busy;

  /// A one-off message for a SnackBar; [messageId] changes with each one so
  /// the same text twice still shows twice.
  final String? message;
  final int messageId;

  /// The tab was deleted: the screen closes.
  final bool deleted;

  const TabDetailState({
    this.status = TabDetailStatus.initial,
    this.ledger,
    this.categories = const {},
    this.byCategory,
    this.errorMessage,
    this.busy = false,
    this.message,
    this.messageId = 0,
    this.deleted = false,
  });

  TabDetailState copyWith({
    TabDetailStatus? status,
    TabLedger? ledger,
    Map<String, ExpenseCategory>? categories,
    Map<String, double>? byCategory,
    bool clearByCategory = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? busy,
    String? message,
    int? messageId,
    bool? deleted,
  }) {
    return TabDetailState(
      status: status ?? this.status,
      ledger: ledger ?? this.ledger,
      categories: categories ?? this.categories,
      byCategory: clearByCategory ? null : (byCategory ?? this.byCategory),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      busy: busy ?? this.busy,
      message: message ?? this.message,
      messageId: messageId ?? this.messageId,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  List<Object?> get props => [
    status,
    ledger,
    categories,
    byCategory,
    errorMessage,
    busy,
    message,
    messageId,
    deleted,
  ];
}
