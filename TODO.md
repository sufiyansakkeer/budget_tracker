# UI/UX Overhaul – Smart Budget Tracker

## Status Legend
- [x] done
- [ ] pending

## Design System Foundation
- [x] Centralize semantic colors in `lib/core/constants/app_colors.dart`
- [x] Add spacing scale (incl. `smd`) in `lib/core/constants/app_spacing.dart`
- [x] Rewrite Material 3 theme in `lib/core/theme/app_theme.dart` (light + dark, typography, radii, components)
- [x] Create reusable design-system components in `lib/core/widgets/`
  - [x] `app_card.dart` (AppCard)
  - [x] `app_section_header.dart` (SectionHeader)
  - [x] `money_text.dart` (MoneyText)
  - [x] `status_chip.dart` (StatusChip)
  - [x] `app_progress.dart` (AppProgress)
  - [x] `empty_state.dart` (EmptyState)
  - [x] `loading_skeleton.dart` (SkeletonBox, DashboardSkeleton, ExpenseListSkeleton)
  - [x] `primary_button.dart` (PrimaryButton)
  - [x] `app_bottom_sheet.dart` (AppBottomSheet)
  - [x] `confirmation_dialog.dart` (ConfirmationDialog)
  - [x] `app_header.dart` (AppHeader)

## App Shell
- [x] Refine NavigationBar in `lib/core/router/app_shell.dart` (safe-area, height, indicator)

## Dashboard
- [x] Rewrite `dashboard_screen.dart` (Hero → Overview → Today's Spending → Timeline → Recent → Insights)
- [x] Replace gradient header with hero card + budget overview
- [x] Add skeleton loading state
- [x] Create `budget_hero_card.dart`, `today_spending_card.dart`
- [x] Update dashboard widgets to use design-system components

## Expenses
- [x] Restyle expense history items with `AppCard`
- [x] Refine search bar + summary + empty/error/skeleton states

## Add / Edit Expense
- [x] Large autofocus amount field
- [x] Visual category grid
- [x] Improved budget picker + date/time + actions

## Budgets
- [x] Redesign budget list cards (progress + active indicator)
- [x] Clean up budget form (date-range summary, grouping)
- [x] Budget list empty/error states use design-system components

## Reports
- [x] Consolidate overview into hero + utilization
- [x] Refine period selector + cards

## Settings
- [x] Settings already structured with grouped `SettingsSection` + reusable `SettingsTile` components

## Verification
- [x] `flutter analyze` — clean (5 pre-existing issues in files not modified: budget_details_screen, settings_screen)
- [x] `flutter test` — all tests for modified files pass. Remaining pre-existing failures (notification/biometric/onboarding/settings_tile) are in unmodified files and required platform channels not present in the pure-Dart test harness or reference pre-existing app/test mismatches.
- [x] Build application — `flutter build apk --debug` succeeded ✓
