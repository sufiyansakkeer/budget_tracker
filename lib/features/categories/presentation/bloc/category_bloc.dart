import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/events/refresh_bus.dart';
import '../../domain/entities/category_failure.dart';
import '../../domain/usecases/archive_category_usecase.dart';
import '../../domain/usecases/delete_category_usecase.dart';
import '../../domain/usecases/load_categories_usecase.dart';
import '../../domain/usecases/save_category_usecase.dart';
import 'category_event.dart';
import 'category_state.dart';

/// Manages the category list and its edits.
///
/// Every successful mutation notifies [RefreshBuses.expenses] because
/// expense rows, filters and reports render category names and colours.
class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final LoadCategoriesUseCase loadCategories;
  final SaveCategoryUseCase saveCategory;
  final ArchiveCategoryUseCase archiveCategory;
  final DeleteCategoryUseCase deleteCategory;

  CategoryBloc({
    required this.loadCategories,
    required this.saveCategory,
    required this.archiveCategory,
    required this.deleteCategory,
  }) : super(const CategoryState()) {
    on<CategoryLoad>(_onLoad);
    on<CategorySave>(_onSave);
    on<CategorySetArchived>(_onSetArchived);
    on<CategoryDelete>(_onDelete);
    on<CategoryClearMessage>(
      (_, emit) => emit(state.copyWith(clearMessages: true)),
    );
  }

  Future<void> _onLoad(CategoryLoad event, Emitter<CategoryState> emit) async {
    if (state.categories.isEmpty) {
      emit(state.copyWith(status: CategoryBlocStatus.loading));
    }
    await _reload(emit);
  }

  Future<void> _onSave(CategorySave event, Emitter<CategoryState> emit) async {
    emit(
      state.copyWith(status: CategoryBlocStatus.saving, clearMessages: true),
    );
    final result = await saveCategory(
      id: event.id,
      name: event.name,
      icon: event.icon,
      colorHex: event.colorHex,
    );
    switch (result) {
      case CategorySuccess(:final data):
        RefreshBuses.expenses.notifyChanged();
        await _reload(
          emit,
          message: event.id == null
              ? '"${data.name}" added'
              : '"${data.name}" updated',
        );
      case CategoryError(:final failure):
        emit(
          state.copyWith(
            status: CategoryBlocStatus.loaded,
            errorMessage: failure.message,
          ),
        );
    }
  }

  Future<void> _onSetArchived(
    CategorySetArchived event,
    Emitter<CategoryState> emit,
  ) async {
    emit(
      state.copyWith(status: CategoryBlocStatus.saving, clearMessages: true),
    );
    final result = await archiveCategory(event.id, archived: event.archived);
    switch (result) {
      case CategorySuccess(:final data):
        RefreshBuses.expenses.notifyChanged();
        await _reload(
          emit,
          message: event.archived
              ? '"${data.name}" archived'
              : '"${data.name}" restored',
        );
      case CategoryError(:final failure):
        emit(
          state.copyWith(
            status: CategoryBlocStatus.loaded,
            errorMessage: failure.message,
          ),
        );
    }
  }

  Future<void> _onDelete(
    CategoryDelete event,
    Emitter<CategoryState> emit,
  ) async {
    emit(
      state.copyWith(status: CategoryBlocStatus.saving, clearMessages: true),
    );
    final result = await deleteCategory(event.id);
    switch (result) {
      case CategorySuccess():
        RefreshBuses.expenses.notifyChanged();
        await _reload(emit, message: 'Category deleted');
      case CategoryError(:final failure):
        emit(
          state.copyWith(
            status: CategoryBlocStatus.loaded,
            errorMessage: failure.message,
          ),
        );
    }
  }

  Future<void> _reload(Emitter<CategoryState> emit, {String? message}) async {
    final result = await loadCategories();
    switch (result) {
      case CategorySuccess(:final data):
        emit(
          state.copyWith(
            status: CategoryBlocStatus.loaded,
            categories: data,
            message: message,
          ),
        );
      case CategoryError(:final failure):
        emit(
          state.copyWith(
            status: CategoryBlocStatus.error,
            errorMessage: failure.message,
          ),
        );
    }
  }
}
