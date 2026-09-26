# Multiple independent budgets

A budget is a pot of money with a name, an amount, a currency and a date
range. You can run several at once — "Monthly", "Trip to Kerala", "Wedding" —
and they never pool.

## What "independent" means

Each budget has its own:

- amount and remaining amount,
- currency,
- start and end date (any range, not just a calendar month),
- expenses (every expense carries exactly one `budgetId`),
- Today's Safe Spending, computed from that budget alone,
- status and projections.

Nothing is ever summed across budgets in a way that implies one pot. The
dashboard shows the active budget's figures, and other budgets running today
appear as separate tiles with their own amounts. The home-screen widget shows
the active budget only. The morning notification prints one line per budget
rather than a total.

The single exception is the budget list's summary card, which adds up the
remaining amounts of the budgets running today purely as an at-a-glance
figure; it is labelled with the first budget's currency and is not used in
any calculation.

## The active budget

One budget at a time is "active". It is what the dashboard, the expense list,
reports, the widget and new expenses default to.

- Stored as a single preference key, `PreferenceKeys.activeBudgetId`
  (`lib/core/constants/preference_keys.dart`), owned by
  `BudgetLocalDataSourceImpl` — no other code reads or writes that string.
- Switched from the dashboard selector, the budget list or settings, always
  through `ManageBudgetUseCase.setActive`, which then fires
  `RefreshBuses.budgets` so every open screen re-reads.
- If the stored id goes stale (the budget was deleted), callers fall back to
  the most recent budget rather than showing an error.

## Lifecycle

`BudgetPhase` (`lib/features/budget/presentation/widgets/budget_visuals.dart`)
derives the state from today's date rather than storing it:

| Phase | Meaning |
| --- | --- |
| upcoming | starts in the future |
| running | today falls inside the period |
| ended | the end date has passed |
| archived | explicitly archived; hidden from pickers, history intact |

"Start a new budget period" (`ResetBudgetUseCase.resetCurrentMonth`) archives
the current budget and creates a fresh one with the same name, amount,
currency and styling, starting today. Both steps run in one transaction, so
either a new period exists and the old one is archived, or nothing changed.
Old expenses stay with the archived budget.

## Money bookkeeping

`remainingAmount` is stored on the budget row as a derived convenience, and
the repository — never a screen — keeps it honest:

- creating, updating or deleting an expense recomputes the affected budget
  inside the same transaction as the write
  (`ExpenseRepositoryImpl`);
- moving an expense between budgets recomputes **both**, so the budget it
  left is credited back;
- changing a budget's amount or dates recomputes it from the expenses that
  actually fall in the period.

## Viewing several budgets together

The expense list has a combined mode: pick a set of budgets and see their
expenses in one list, with a tag on each row showing which budget it belongs
to. This is a *view*. The budgets themselves are untouched, each row still
formats in its own budget's currency, and leaving the mode returns to the
active budget.

## Tests that pin it

- `test/integration/budget_flows_test.dart` — creating, switching, deleting,
  starting a new period, and that switching re-scopes every figure.
- `test/features/expenses/presentation/bloc/expense_history_combined_mode_test.dart`
  — combined selection, search and filters across budgets.
