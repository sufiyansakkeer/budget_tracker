# Smart Monivo v1.2.2

## What's New

### Combined Expense History Mode
- View and compare expenses from multiple budgets in a single unified list.
- Tap the combine button on the expense history screen to enter combined mode.
- Each expense tile displays a budget name chip so you can see which budget
  it belongs to.
- Tap the info icon on an expense to open a bottom sheet with full budget details.

### Budget Selection Sheet
- Choose which budgets to include in combined mode via a dedicated selection sheet.
- Select or deselect individual budgets, or use the search bar to quickly find
  a budget by name.
- The selection is preserved when the screen refreshes.

### Sort by Amount
- Expense history now supports sorting expenses ascending or descending by
  amount, in addition to the existing date-based grouping.

## Improvements

### Refactored Expense History
- The expense history screen and BLoC have been refactored to cleanly support
  both single-budget and combined modes.
- Expense grouping and sorting use cases now work correctly across multiple
  budgets in combined mode.

## Bug Fixes

- Added missing INTERNET permission to AndroidManifest for GitHub release
  checks to work on Android.

## Technical Changes

- Added combined-mode tests covering budget selection, expense filtering,
  search, category filtering, date filtering, and state persistence.
- Added combined-mode widget tests for ExpenseHistoryItem, BudgetInfoBottomSheet,
  and BudgetSelectionSheet.
- Added integration tests for sorting expenses by amount in expense history.
- Enhanced test coverage for expense history BLoC, use cases, and data sources.

## Known Issues

- None at this time.
