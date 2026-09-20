# Monivo 1.2.3

## What's New

### Colour Palettes
- Choose from eight colour palettes: Default, Blossom Vapor, Mahogany Blaze,
  Ocean, Forest, Sunset, Violet and Rose.
- Pick one from **Settings → Appearance → Colour palette**. Your choice is
  remembered and works with Light, Dark and System modes.
- Switching a palette or flipping between light and dark now fades smoothly
  instead of snapping — no restart needed.

### A Calmer, More Responsive Interface
- Screens now slide and fade between each other instead of cutting, and
  switching bottom-navigation tabs cross-fades.
- Amounts count up to their new value, progress bars sweep, and charts reveal
  themselves the first time they appear.
- Cards and buttons give a subtle press response, and lists ease in as they
  load.
- If your device has "reduce motion" turned on, Monivo respects it and keeps
  animations to a minimum.

### Clearer Notifications
- Android notifications now use a proper monochrome status-bar icon and
  Monivo's accent colour, for both daily budget reminders and bill reminders.

## Improvements

- Every explanation in the app — info sheets, empty states, onboarding,
  Settings descriptions, notification text and the widget description — was
  rewritten to match how Monivo actually works: multiple independent budgets,
  flexible start and end dates, and a Today's Safe Spending figure that is
  calculated per budget and never combined across budgets.
- Consistent wording everywhere: Today's Safe Spending, Spent today, budget
  period, active budget and Combined Expenses now mean the same thing on every
  screen.
- The Dashboard's separate remaining and timeline cards have been merged into
  one budget overview card. It shows what is left (or how far over you are),
  the percentage used, and where you are in the budget period.
- The Settings budget actions now say exactly what they do: **Budgets**,
  **Start new budget period** and **Change active budget amount**.
- The status bar now matches the theme you are using on screens without a
  toolbar.
- Toggles that had no effect — Overspending Alerts, No-Expense Reminder and
  Quiet Hours — have been removed from Settings.

## Bug Fixes

- **Today's Safe Spending no longer shrinks as you spend.** The Dashboard
  cards, notifications and the home screen widget all use the same calculation
  as the budget engine, so the figure stays fixed for the day. Previously,
  spending exactly your safe amount could show as "Over limit".
- **Changing your budget amount keeps your expenses.** Editing the Active
  Budget's amount from Settings now correctly reflects what you have already
  spent in the remaining balance.
- **Reports comparisons work.** Growth rate and the week-over-week card now
  compare against the previous period instead of always comparing against zero.
- **Category sort is stable.** Sorting the expense history by category now
  keeps expenses ordered by category within each day.
- **"Create Budget" works on the Dashboard.** When no budget covers today, the
  button now opens the budget form.

## Other Changes

- The app is consistently called **Monivo** throughout — onboarding, the About
  card, the home screen widget and the documentation — rather than a mix of
  "Smart Monivo", "Smart Budget Tracker" and "Monivo".
- The project documentation (README, changelog and release notes) has been
  rewritten against the source so it describes what the app actually does,
  including an honest list of known limitations.

## Upgrade Notes

No action needed. This release contains no database migration and no breaking
changes — your budgets, expenses and bills carry over as they are.
