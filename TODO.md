# Phase 5 – Expense Management Module TODO

## Database
- [x] Add `time` column to Expenses table + index on date/categoryId (schema v2 migration)
- [x] Regenerate drift `app_database.g.dart`

## Domain
- [x] Create `ExpenseEntity`
- [x] Create `ExpenseCategory` + default categories
- [x] Create `ExpenseFailure`/`ExpenseResult` typed errors
- [x] Create `ExpenseRepository` interface
- [x] Create `ExpenseValidator`
- [x] Create use cases: Create, Update, Delete, GetById, GetCategories, GetExpenses

## Data
- [x] Create `ExpenseModel` + `ExpenseCategoryModel`
- [x] Create `ExpenseLocalDataSource` + impl
- [x] Create `ExpenseRepositoryImpl`

## BLoC
- [x] Create `ExpenseEvent`, `ExpenseState`, `ExpenseBloc`
- [x] Create `ExpenseRefreshBus` (Budget/Dashboard auto-refresh)

## Presentation
- [x] Create reusable widgets (Amount, Category, Date, Time, Receipt, Note, Tags, FormActions, DeleteDialog, SummaryCard)
- [x] Create `ExpenseFormScreen` (add & edit)
- [x] Create `ExpenseDetailsScreen`
- [x] Create `ExpensesListScreen`

## Navigation
- [x] Update GoRouter routes

## DI
- [x] Register expenses datasource/repository/usecases/bloc in DI

## Receipt
- [x] Add camera permission to AndroidManifest + iOS Info.plist

## Tests
- [x] Unit: repository, use cases, validators
- [x] Widget: add/edit form, category picker, receipt picker, validation

## Verification
- [x] `flutter analyze` passes
- [x] `flutter test` passes (123 tests)
- [x] Build passes (`flutter build apk --debug`)
