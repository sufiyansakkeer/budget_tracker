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

### Home Screen Widget
- View a spending overview directly from your device's home screen without
  opening the app.
- Displays budget summaries with remaining amounts and today's spending.
- Supported on both Android (App Widgets) and iOS (WidgetKit).
- Widget data updates automatically when expenses are added or modified.
- Tap a budget in the widget to open the app directly to that budget's
  details.

### Database Integrity Service
- Comprehensive data integrity checks for budgets, expenses, and bills.
- Automatic detection of orphaned records, broken foreign key references,
  and inconsistent data states.
- Repair workflows to fix integrity issues during backup/restore and data
  import operations.
- Integrity validation is integrated into the backup and restore pipeline
  to prevent data corruption.

## Improvements

### Refactored Expense History
- The expense history screen and BLoC have been refactored to cleanly support
  both single-budget and combined modes.
- Expense grouping and sorting use cases now work correctly across multiple
  budgets in combined mode.

### UI Color Scheme & Accessibility
- Refactored dashboard, expense, and report components to use centralized
  color schemes from `AppTheme` for a more consistent visual experience.
- Improved accessibility across empty states, error widgets, and progress
  cards with better contrast and semantic styling.

### Navigation Refactoring
- Updated routing configuration for expenses and budgets with improved
  screen transitions and deep link handling.
- Enhanced widget routing logic for expense-related URIs.

### Backup & Import
- Backup and import services now perform integrity-aware validation before
  completing data operations.

## Bug Fixes

- Added missing INTERNET permission to AndroidManifest for GitHub release
  checks to work on Android.
- Fixed widget routing to correctly handle expense-related deep links from
  the home screen widget.

## Technical Changes

- Added combined-mode tests covering budget selection, expense filtering,
  search, category filtering, date filtering, and state persistence.
- Added combined-mode widget tests for ExpenseHistoryItem, BudgetInfoBottomSheet,
  and BudgetSelectionSheet.
- Added integration tests for sorting expenses by amount in expense history.
- Enhanced test coverage for expense history BLoC, use cases, and data sources.
- Added `HomeWidgetService` for managing widget data and lifecycle events.
- Added `WidgetRefreshListener` to keep widget data in sync with app state.
- Added Database Integrity Service tests covering orphan detection,
  referential integrity validation, and repair workflows.
- Added data integrity validator tests for backup and restore operations.
- Added expense transaction safety tests for concurrent modification
  scenarios.
- Enhanced sort integration tests for expense history.
- Updated navigation and backup validation tests.

## Known Issues

- None at this time.
