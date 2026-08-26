# Smart Monivo v1.2.1

## What's New

### Per-Budget Daily Spending Limits
- Each active budget now has its own daily and weekly spending targets calculated automatically based on remaining amount and days.
- A dedicated section on the Dashboard shows daily limits for every budget, including progress bars, spent amounts, remaining amounts, and over-limit indicators.
- Weekly spending targets are tracked alongside daily limits for better planning.

### Improved Dashboard Layout
- The dashboard hero card and spending target cards have been refactored into separate, focused widgets for better maintainability.
- Spending target display has been improved with clearer visual status indicators.

### Enhanced Bottom Sheet & Info Icons
- `AppBottomSheet` and `InfoIcon` components now have improved bottom sheet behavior and state management.
- Info icons provide detailed explanations of analytics metrics with how they are calculated.

## Improvements

### Dynamic Morning Notifications
- Morning notifications now dynamically calculate the safe spending amount based on each budget's daily limit, rather than using a static value.

### App Update Checker
- The app can check GitHub for newer releases from **Settings > App Updates**.
- When a release is available, users can view the release page in their browser.

### Bill Management
- Track due dates, payment status, recurring bills, and payment reminders.
- Bills are managed separately from ordinary expenses.
- Search, filter by status, open details, and mark bills as paid.
- Recurring bills are generated according to their recurrence rule.

### Settings Screen
- Dedicated Settings screen with links to expenses and bills.
- Options for appearance, currency, notification, security, data, and updates.

### Currency Selection
- Choose currency when creating or editing a budget.
- Default currency configurable in Settings.

### Analytics Explanations
- Information icons on analytics cards show what each metric means, how it is calculated, and notes about status colors.

### Expense History
- Groups expenses by the device's local calendar date.

## Bug Fixes

- Improved notification recovery and reliability, including handling after device restarts.
- BillEntity `dueToday` status checks now have improved test coverage and formatting.
- Android keystore files added to `.gitignore`.

## Technical Changes

- Refactored `GetSmartInsightsUseCase` and `GetSpendingTargetsUseCase` to support per-budget daily limits.
- New `BudgetDailyLimitEntity` for per-budget daily limit calculations.
- Updated CI/CD release workflow configuration.
- Enhanced test coverage for BillBloc, BillEntity, notification service, and spending target cards.

## Known Issues

- None at this time.
