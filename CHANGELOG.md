# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Audited and rewrote all user-facing explanations (info sheets, empty states,
	onboarding, Settings descriptions, notifications, widget descriptions) to
	match the current implementation: multiple independent budgets, flexible
	start/end dates, per-budget Today's Safe Spending that is never combined,
	and rule-based (non-AI) Smart Insights.
- Standardised terminology across the app: Today's Safe Spending, Spent Today,
	Remaining Today, Remaining Budget, Overall Budget Progress, Active Budget,
	Budget Period, Combined Expenses.
- Dashboard "Total Remaining" card renamed to "Remaining Budget"; it always
	reflected the active budget only.
- Settings "Budget Management" renamed to "Active Budget" with accurate labels
	("Start New Budget Period", "Change Budget Amount").
- Removed the Overspending Alerts, No-Expense Reminder and Quiet Hours toggles
	from Settings because no notification logic implements them.
- Home-screen widget now shows the active budget's Today's Safe Spending
	instead of a sum across budgets.
- Smart Insights and report insights no longer refer to a "monthly" budget or
	use combined daily targets; the over-budget insight reports the actual
	overspend.
- The app is now consistently called "Monivo" (matching the installed app
	label) in the onboarding, About card, widget and README instead of a mix of
	"Smart Monivo", "Smart Budget Tracker" and "Monivo".
- Corrected the v1.2.2 release-note bullets for the home-screen widget, which
	described behaviour that never shipped.

### Fixed
- Today's Safe Spending on the Dashboard cards, notifications and widget now
	uses the same formula as the budget engine: (remaining + spent today) ÷
	remaining days. Previously the per-budget cards shrank the amount as you
	spent, so spending exactly the safe amount showed as "Over limit".
- Bill and budget-list tests that hard-coded August 2026 dates now use dates
	relative to today, so they no longer fail once that month has passed.
- Reports growth rate and week-over-week comparison now receive the expenses
	from the preceding period, so they no longer always compare against zero.
- "Category" sort in the expense history now keeps expenses ordered by
	category within each day group.
- Changing the active budget's amount from Settings now keeps existing
	expenses reflected in the remaining amount.
- The "Create Budget" button shown on the Dashboard when no budget covers
	today now opens the budget form.
- Removed unused dashboard widgets that still described combined daily limits.

## [1.2.2] - 2026-08-31

### Added
- Combined expense history mode that lets users view and compare expenses
	across multiple budgets in a single unified list, with budget name chips
	on each expense tile.
- Budget selection sheet for choosing which budgets to include in combined
	mode, with support for selecting, deselecting, and searching budgets.
- Sort-by-amount support in expense history for ordering expenses
	ascending or descending by amount.
- Home screen widget for Android and iOS that displays a spending overview
	with budget summaries directly on the device home screen.
- `HomeWidgetService` for managing widget data updates and lifecycle events.
- `WidgetRefreshListener` to keep widget data in sync with app state changes.
- Database Integrity Service for comprehensive data integrity checks,
	including orphaned record detection, referential integrity validation,
	and automatic repair capabilities.

### Changed
- Refactored expense history screen and BLoC to support a combined view
	mode alongside the existing single-budget mode.
- Enhanced expense grouping and sorting use cases to work across multiple
	budgets in combined mode.
- Refactored UI components across dashboard, expenses, and reports screens
	to use centralized color schemes from `AppTheme` and improve accessibility.
- Refactored navigation routes for expenses and budgets with updated
	routing configuration and improved screen transitions.
- Enhanced backup and import services with integrity-aware validation.
- Updated widget routing logic for expense-related URIs.

### Fixed
- Added missing INTERNET permission to AndroidManifest for GitHub release
	checks.
- Improved widget routing to correctly handle expense-related deep links.

### Technical
- Added combined-mode tests covering budget selection, expense filtering,
	search, category filtering, date filtering, and state persistence.
- Added combined-mode widget tests for ExpenseHistoryItem, BudgetInfoBottomSheet,
	and BudgetSelectionSheet.
- Added integration tests for sorting expenses by amount in expense history.
- Enhanced test coverage for expense history BLoC, use cases, and data sources.
- Added Database Integrity Service tests covering orphan detection,
	referential integrity validation, and repair workflows.
- Added data integrity validator tests for backup and restore operations.
- Added expense transaction safety tests for concurrent modification
	scenarios.
- Enhanced sort integration tests for expense history.
- Updated navigation and backup validation tests.

## [1.2.1] - 2026-08-26

### Added
- Per-budget daily spending limits with individual daily and weekly targets for
	each active budget, displayed in a dedicated dashboard section.

### Changed
- Refactored dashboard spending target implementation to separate hero card
	and spending target widgets for better maintainability.
- Improved AppBottomSheet and InfoIcon components with enhanced bottom sheet
	behavior and state management.
- Morning notifications now dynamically calculate the safe spending amount
	based on each budget's daily limit.

### Fixed
- Improved test formatting for BillEntity `dueToday` status checks and
	enhanced BillBloc test coverage.
- Updated `.gitignore` to include Android keystore files.
- Updated CI/CD release workflow configuration.

## [1.2.0] - 2026-08-26

### Added
- Bill management improvements for tracking due dates, payment status, recurring
	bills, and payment reminders.
- An app update checker that reports new GitHub releases and opens their release
	page from the Settings screen.
- Explanations for analytics cards so users can see how each metric is
	calculated.

### Changed
- Added a dedicated Settings screen with links to expenses and bills, along
	with appearance, currency, notification, security, data, and update options.
- Budget forms now use selectable currency codes and symbols from the supported
	currency list.
- Expense history groups entries by the device's local calendar date.

### Fixed
- Improved notification recovery and reliability, including handling after
	device restarts.

## [1.1.0] - 2026-08-25

### Added
- Notification management with morning reminders, evening summaries,
	overspending alerts, no-expense reminders, and quiet hours.
- Currency selection when creating or editing a budget.

### Changed
- Expense history now groups expenses according to the device's local date.
- Updated the notification dependency and Android configuration to improve
	reminder handling.
- Added automated Android and iOS build and release workflows.

## [1.0.2] - 2026-08-17

### Fixed
- **Notifications**: Resolved bugs related to notifications not displaying correctly or triggering unexpectedly. Improved reliability for notification handling.

### Changed
- **Icons**: Updated app icons for better visual consistency and clarity. Optimized for all device resolutions and themes.

## [1.0.1] - 2026-08-11

### Fixed
- Initial bug fixes and minor improvements.

## [1.0.0] - 2026-08-11

### Added
- Initial release of the Budget Tracker app.
