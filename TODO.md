# Phase 6 – Expense History & Search Module TODO

## Domain – New Files
- [x] Create `domain/entities/expense_history_filter.dart`
- [x] Create `domain/entities/expense_history_sort.dart`
- [x] Create `domain/entities/expense_history_summary.dart`
- [x] Create `domain/entities/expense_group.dart`
- [x] Create `domain/usecases/search_expenses_usecase.dart`
- [x] Create `domain/usecases/filter_expenses_usecase.dart`
- [x] Create `domain/usecases/sort_expenses_usecase.dart`
- [x] Create `domain/usecases/calculate_expense_summary_usecase.dart`
- [x] Create `domain/usecases/group_expenses_usecase.dart`
- [x] Create `domain/usecases/page_expenses_usecase.dart`

## Presentation – History Module
- [x] Create `presentation/history/bloc/expense_history_event.dart`
- [x] Create `presentation/history/bloc/expense_history_state.dart`
- [x] Create `presentation/history/bloc/expense_history_bloc.dart`
- [x] Create `presentation/history/widgets/expense_history_item.dart`
- [x] Create `presentation/history/widgets/expense_group_header.dart`
- [x] Create `presentation/history/widgets/expense_search_bar.dart`
- [x] Create `presentation/history/widgets/filter_bottom_sheet.dart`
- [x] Create `presentation/history/widgets/sort_bottom_sheet.dart`
- [x] Create `presentation/history/widgets/summary_card.dart`
- [x] Create `presentation/history/widgets/active_filter_chips.dart`
- [x] Create `presentation/history/widgets/quick_filter_chips.dart`
- [x] Create `presentation/history/widgets/expense_history_empty_state.dart`
- [x] Create `presentation/history/widgets/expense_history_error_widget.dart`
- [x] Create `presentation/history/widgets/loading_more_indicator.dart`
- [x] Create `presentation/history/pages/expense_history_screen.dart`

## Integration
- [x] Update `core/router/app_router.dart` – add `/expenses/history` route
- [x] Update `core/di/injection.dart` – register history use cases + bloc
- [x] Update `expenses_list_screen.dart` – history entry point

## Tests
- [x] Unit tests: search, filter, sort, summary, pagination, grouping
- [x] `ExpenseHistoryBloc` test
- [x] Widget tests: history screen, search bar, filter sheet, sort sheet, empty/error states

## Verification
- [x] `flutter analyze` passes (only 3 pre-existing info lints)
- [x] `flutter test` passes (163 tests)
- [x] Summary of completed functionality
