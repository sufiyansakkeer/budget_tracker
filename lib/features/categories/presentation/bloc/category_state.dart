import 'package:equatable/equatable.dart';

import '../../../expenses/domain/entities/expense_category.dart';

enum CategoryBlocStatus { initial, loading, loaded, saving, error }

class CategoryState extends Equatable {
  final CategoryBlocStatus status;

  /// Active first, then archived; alphabetical within each group.
  final List<ExpenseCategory> categories;

  /// One-shot success feedback (cleared with [CategoryClearMessage]).
  final String? message;

  /// One-shot failure feedback.
  final String? errorMessage;

  const CategoryState({
    this.status = CategoryBlocStatus.initial,
    this.categories = const [],
    this.message,
    this.errorMessage,
  });

  List<ExpenseCategory> get active =>
      categories.where((c) => !c.isArchived).toList();

  List<ExpenseCategory> get archived =>
      categories.where((c) => c.isArchived).toList();

  bool get isBusy =>
      status == CategoryBlocStatus.loading ||
      status == CategoryBlocStatus.saving;

  CategoryState copyWith({
    CategoryBlocStatus? status,
    List<ExpenseCategory>? categories,
    String? message,
    String? errorMessage,
    bool clearMessages = false,
  }) {
    return CategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      message: clearMessages ? null : (message ?? this.message),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, categories, message, errorMessage];
}
