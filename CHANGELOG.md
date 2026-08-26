# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
