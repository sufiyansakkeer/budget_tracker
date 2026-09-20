# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.3] - 2026-09-20

### Added
- Eight selectable colour palettes (Default, Blossom Vapor, Mahogany Blaze,
	Ocean, Forest, Sunset, Violet, Rose) with a dedicated palette selection
	screen in Settings. The palette is persisted and applies to both light and
	dark themes.
- A shared motion system: central motion tokens (`AppMotion`), consistent page
	transitions (`AppPageTransitions`), animated dialogs (`AppDialog`), an
	animated floating action button (`AppFab`), chart reveal animations
	(`ChartReveal`) and staggered list entrances (`FadeSlideIn`). Every
	animation honours the platform's reduced-motion setting.
- A dedicated monochrome notification icon and brand accent colour for Android
	notifications, applied to both budget and bill reminder channels.

### Changed
- Audited and rewrote all user-facing explanations (info sheets, empty states,
	onboarding, Settings descriptions, notifications, widget descriptions) to
	match the current implementation: multiple independent budgets, flexible
	start/end dates, per-budget Today's Safe Spending that is never combined,
	and rule-based (non-AI) Smart Insights.
- Standardised terminology across the app around Today's Safe Spending, Spent
	today, budget period, active budget and Combined Expenses, so the same figure
	is not called different things on different screens.
- Merged the separate Remaining Budget and Budget Timeline cards on the
	Dashboard into a single budget overview card, so the same facts are not
	repeated. It shows what is left (or how far over), the percentage used, and
	the position in the budget period.
- Reworded the Settings budget section so each action says what it does:
	"Budgets" (create, switch, edit and archive), "Start new budget period"
	(archive the active budget and start a fresh 31-day one with the same amount)
	and "Change active budget amount" (dates and expenses stay as they are).
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
- Rewrote README, CHANGELOG and release notes against the source. Removed
	unverifiable claims (line counts, coverage figures, performance benchmarks, a
	`logger` dependency that is not used, an MIT licence with no `LICENSE` file)
	and corrected the v1.2.2 home-screen widget description, which described
	behaviour that never shipped. Added a Known Limitations section covering the
	unwired database integrity service, the unused `recurring_expenses` and
	`savings_goals` tables, the vestigial notification preference fields, the
	orphaned `ResetMonthUseCase` and the declared-but-unused dependencies.
- Theme mode and palette changes now interpolate every colour in place instead
	of switching abruptly, and the system status-bar style follows the active
	theme brightness on screens without an app bar.
- Bottom-navigation branches cross-fade when switching tabs, and re-selecting
	the current tab plays a single icon pulse.
- Refactored the Settings screen components for consistent spacing, contrast
	and semantics.
- Reworked the Reports and notification copy for accuracy about what each
	figure measures.

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

### Technical
- Budget amount updates now run inside a database transaction and recompute the
	stored remaining amount from the persisted expenses within that same
	transaction, so a concurrent write cannot leave a stale balance.
- Added regression tests for budget amount changes and for editing a budget
	from the Dashboard.

### Breaking changes
- None. No database migration (the schema stays at version 4), no minimum SDK
	change, no navigation or data-model change, and no removed functionality.

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
