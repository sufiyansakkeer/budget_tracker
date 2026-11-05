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

  /// How many expenses use each custom category, by id; missing when it
  /// couldn't be read. Built-in ones are never deleted, so never counted.
  final Map<String, int> usage;

  const CategoryState({
    this.status = CategoryBlocStatus.initial,
    this.categories = const [],
    this.message,
    this.errorMessage,
    this.usage = const {},
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
    Map<String, int>? usage,
    bool clearMessages = false,
  }) {
    return CategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      message: clearMessages ? null : (message ?? this.message),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      usage: usage ?? this.usage,
    );
  }

  @override
  List<Object?> get props => [status, categories, message, errorMessage, usage];
}
