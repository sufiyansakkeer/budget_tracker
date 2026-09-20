# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-09-20

A feature release built on a review of the app against the `Money-Tracker`
reference project (see `docs/money_tracker_gap_analysis.md`), plus the internal
cleanups that review surfaced.

### Added
- **Category management.** Settings → Expenses → Categories creates, renames and
  restyles categories from a catalogue of 43 icons and 16 colours, archives ones
  you no longer use, and deletes custom categories that no expense references.
  Built-in categories can be renamed and restyled but not deleted. Archived
  categories disappear from pickers and quick filters while history keeps its
  labels. New `isArchived` column on `categories`.
- **Undo after deleting an expense.** Swiping a row deletes it immediately and
  offers Undo in a snackbar for a few seconds; undoing restores the same row, so
  budgets, reports and the widget stay consistent either way. The confirmation
  dialog on swipe is gone; the details screen still confirms.
- **Press and hold an expense** for Edit, Duplicate, Move to another budget and
  Delete. Duplicate opens the form pre-filled from that expense, dated now.
- **Date presets** — Today, Yesterday, This week, Last week, This month, Last
  month, This year — as quick chips and in the filter sheet. A custom range now
  reads as one chip ("12 Mar – 15 Mar") instead of a From/To pair.
- **Animated bottom navigation** using Rive icons on the Material 3 bar. The
  selected tab plays a short one-shot animation while the bar draws the steady
  selected state from the current index, so it is correct after navigating,
  after returning from a screen and after a restart. Nothing loops, the icon
  falls back to its Material glyph if the asset cannot load, and reduced motion
  skips the animation. New `lib/core/navigation/` module and `rive` dependency.
- **Categories vs previous period** report card: which categories moved most
  against the equal-length window before the selected range, with the change in
  money and percent and a "New" marker.
- **A weekly line on the safe-spending hero** — what has been spent against this
  week's share of the budget.
- **Database health check** in Settings → Data, which runs the previously unwired
  `DatabaseIntegrityService` and reports orphaned rows, impossible date ranges and
  invalid amounts in a sheet.
- **Architecture documentation** in `docs/architecture/`: why Drift, BLoC, Clean
  Architecture and GetIt; how safe spending is calculated; how multiple budgets
  work; how the Rive navigation works; the offline-first data contract; the
  notification architecture; and what backup, restore, export and import cover.
- **Integration tests** (`test/integration/`) that wire the real datasources,
  repositories, use cases and BLoCs against an in-memory database and drive whole
  flows end to end, plus a v4 → v5 schema migration test against a captured
  schema fixture.

### Fixed
- **Moving an expense to another budget left the budget it came from short.**
  Only the destination budget's remaining amount was recomputed, so the source
  budget stayed reduced by the amount for good. Both budgets are now recomputed
  inside the same transaction.
- **Foreign keys were declared but never enforced.** `PRAGMA foreign_keys` is now
  on for every connection, so an expense can no longer reference a budget or
  category that does not exist. The v5 migration repairs existing databases
  first: it re-points dangling references, seeds missing categories and fixes
  databases whose v3 migration wrote camelCase column names.
- **Three different formulas for Today's Safe Spending.** The dashboard added
  today's spending back before dividing while `CalculateDailyAllowanceUseCase`
  and one branch of the spending targets did not, so the same figure could differ
  between screens. There is now one implementation,
  `BudgetCalculationService.calculateTodaySafeSpending`, and the rules document
  matches it.
- **CSV exports could not be re-imported.** The exporter and importer disagreed
  on columns, and the importer split on commas, so any quoted field broke it. The
  export is now one spreadsheet-friendly expense table and the importer matches
  columns by header name, tolerates rearranged files, and falls back to "Others"
  for unknown categories rather than failing.
- **The morning notification showed a stale safe-spending figure**, because a
  repeating notification stores its text when it is scheduled. It is now
  re-scheduled after expense and budget changes, debounced.
- **Upcoming bills on the dashboard were not sorted by due date**, despite the
  section presenting them as what is next.
- **Recurring bill totals ignored the interval**, so a bill due every two months
  counted as monthly.
- The backup file's recorded app version was hard-coded and had drifted from the
  real one; it now comes from the package metadata.
- The expense list briefly published a "loaded" state with an empty list before
  filtering, which could flash the empty state.
- Skeleton shimmer kept a ticker running when the platform asked for reduced
  motion.

### Changed
- **Budget statistics and bill totals are computed in SQL** (`SUM`/`COUNT` over
  the indexed columns) instead of loading every row into Dart, with a new
  composite `(budget_id, date)` index behind the hottest query.
- **One refresh bus implementation** (`lib/core/events/refresh_bus.dart`) replaces
  three copy-pasted ones; `RefreshBuses.expenses`, `.budgets` and `.bills`.
- **One place owns each shared key and value.** `PreferenceKeys` holds the
  active-budget id and first-launch flag, previously declared in three files; the
  default category list has a single definition used by both the database and the
  expenses feature; onboarding uses the shared currency and budget entities
  instead of its own copies.
- `ResetBudgetUseCase` goes through `BudgetRepository` instead of writing to Drift
  directly, so remaining amounts are derived in one place.
- The two near-identical app-update dialogs were merged into one.
- Settings shows the configured morning and evening times on the notifications
  row.

### Accessibility
- **Screen-reader activation worked on almost nothing.** Fifteen controls used
  `Semantics(button: true)` wrapped around `ExcludeSemantics`, which publishes
  a node that says "button" but carries no tap action, so TalkBack and
  VoiceOver "activate" did nothing (pointer taps still worked, which is why it
  went unnoticed). Expense rows, budget cards, recent expenses, insights, the
  active-budget selector, date/time/colour pickers, theme and palette tiles,
  bill cards and the onboarding date step are now activatable.
- A bill's "Mark as paid" button was swallowed by the merged card node and was
  unreachable; it is exposed as a custom action.
- **Contrast**: the app's muted supporting-text colour measured 3.7:1, so
  every piece of secondary text failed AA. Text tokens are now guaranteed AA
  in all eight palettes, category colours are contrast-driven rather than
  lightness-clamped (several catalogue hues were below 2:1), and status chips,
  status cards, progress labels, budget tags, tag chips, the combined-mode
  banner, report trend text and the safe-spending metrics derive a legible
  variant of their accent instead of drawing it raw. The destructive dialog
  button, the category error snackbar and the amount hint were 3.8:1, 1.4:1
  and 1.5:1.
- **Touch targets**: four controls had density overrides that took them to
  40×40, including the info icon used in thirteen places.
- **Text scaling**: the navigation bar clamps scaling the way Material's own
  bar does, and fixed-height boxes that clipped at large font sizes are now
  minimums.
- **Reduced motion**: onboarding page slides, scroll-to-error and
  swipe-to-delete now honour the setting.
- New `test/accessibility/guidelines_test.dart` runs Flutter's tap-target,
  labelling and contrast guidelines over representative screens; it found the
  navigation-label and hero-metric contrast failures above.

### Performance
- `runApp` no longer waits for notification initialisation, which parses the
  time-zone database, crosses several platform channels and shows the
  permission dialog — an unbounded, user-gated delay on the splash screen.
- Loading settings was one query per key, and four layers loaded them in full
  at startup: roughly sixty round-trips before the first frame, now one.
- Today's spending is a single indexed `SUM` instead of re-reading the budget
  row and summing the whole period to discard both; it runs once per budget on
  every dashboard load, widget refresh and notification reschedule.
- Expense queries take a date range served by the `(budget_id, date)` index.
  A report reads only its window, and reads it once instead of twice.
- The dashboard's upcoming bills come from an ordered, limited query.
- The integrity check is anti-joins instead of three full table reads folded
  on the UI isolate.
- Narrower rebuilds: typing in the expense search rebuilt every visible row
  per keystroke, a report status flip rebuilt all three charts, and every
  snackbar rebuilt the settings list twice.
- Each Rive navigation icon sits behind a repaint boundary so its per-frame
  repaint cannot escape into the rest of the bar.

### Removed
- The orphaned `ResetMonthUseCase`, which was not registered anywhere and would
  have created a zero-amount budget.
- Two dead dashboard widgets, the onboarding re-export files, and the empty
  placeholder `create_budget_usecase.dart` in the budget feature.
- Unused dependencies: `freezed`, `freezed_annotation`, `json_serializable`,
  `json_annotation`, `printing`, `collection`, `cupertino_icons`, and four
  misplaced `: any` entries that were nested under `flutter_launcher_icons` and
  had no effect.

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
