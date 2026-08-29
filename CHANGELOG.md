# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.2] - 2026-08-30

### Added
- Combined expense history mode that lets users view and compare expenses
	across multiple budgets in a single unified list, with budget name chips
	on each expense tile.
- Budget selection sheet for choosing which budgets to include in combined
	mode, with support for selecting, deselecting, and searching budgets.
- Sort-by-amount support in expense history for ordering expenses
	ascending or descending by amount.

### Changed
- Refactored expense history screen and BLoC to support a combined view
	mode alongside the existing single-budget mode.
- Enhanced expense grouping and sorting use cases to work across multiple
	budgets in combined mode.

### Fixed
- Added missing INTERNET permission to AndroidManifest for GitHub release
	checks.

### Technical
- Added combined-mode tests covering budget selection, expense filtering,
	search, category filtering, date filtering, and state persistence.
- Added combined-mode widget tests for ExpenseHistoryItem, BudgetInfoBottomSheet,
	and BudgetSelectionSheet.
- Added integration tests for sorting expenses by amount in expense history.
- Enhanced test coverage for expense history BLoC, use cases, and data sources.

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
