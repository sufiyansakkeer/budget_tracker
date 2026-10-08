# Today's Safe Spending

This is the number shown on the dashboard hero, in "Other budgets today", in
the morning notification and on the home-screen widget. It answers one
question: *after the bills this budget still has to pay, the money I keep
aside and my savings goal, what can I spend today?*

Full formulas, thresholds and edge cases are in
[`lib/features/budget/CALCULATION_RULES.md`](../../lib/features/budget/CALCULATION_RULES.md).
This page explains how the pieces fit together, and why.

## The formula

```
Remaining in budget (A) = budget amount − spending in this budget's period
Free to spend           = A − bills due (B) − kept aside (C) − savings goal (D)

Today's Safe Spending   = max(0, (Free to spend, signed + today's discretionary spending)
                                 ÷ remaining days)
```

- **Bills due (B):** unpaid occurrences of the bills linked to this budget,
  due up to the end of the period. This includes overdue occurrences, which
  are still owed.
- **Kept aside (C)** and **Savings goal (D)** are optional per-budget amounts.
  Each one is either "Not set" (null) or a value of 0 or more.
- **Today's discretionary spending** is today's expenses in this budget,
  minus the bill payments that settled money this budget had set aside.
- **Remaining days** counts calendar days and includes today (minimum 1).

The daily figure stays fixed for the whole day: today's discretionary
spending is added back before dividing, and then compared against the result
("₹300 spent of ₹868.18"). Unspent money is not banked or removed. Tomorrow's
figure is recomputed from what is actually left, so an underspent day raises
it and an overspent day lowers it.

With no bills, nothing kept aside and no savings goal, the formula is exactly
the earlier one, `(remaining + spent today) ÷ remaining days`. Tests assert
that both give the same number.

## Where it lives

| Piece | File | Role |
|---|---|---|
| `SafeToSpendCalculator` | `lib/features/budget/domain/services/safe_to_spend_calculator.dart` | Pure engine: phase, A/B/C/D, daily figure, status, reasons, forecast |
| `BudgetCalculationService` | `lib/features/budget/domain/services/budget_calculation_service.dart` | Calendar day counts and the one division (`calculateTodaySafeSpending`) |
| `MoneyMath` | `lib/core/currency/money_math.dart` | Integer-unit money arithmetic |
| `BillOccurrenceEnumerator` | `lib/features/dashboard/domain/services/bill_occurrence_enumerator.dart` | Pure: which bill occurrences a budget deducts, plus "not linked" and "other currency" disclosures |
| `GetSafeToSpendUseCase` | `lib/features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart` | Reads the inputs and runs the engine for one budget or many |
| `SafeToSpendEntity` | `lib/features/budget/domain/entities/safe_to_spend/` | The result. Every figure on screen comes from it. |

The engine imports nothing from the bills feature. It sees bills only as
primitive `CommitmentOccurrence`s (bill id, title, amount, due date,
overdue). It has no clock: "today" is passed in.

## One number everywhere

`GetSpendingTargetsUseCase.callPerBudget` runs the engine once for all
running budgets with `callForBudgets`, which does one bills read and one
committed-spending read. It then attaches each budget's entity to its
`BudgetDailyLimitEntity.safeToSpend`. The surfaces that show a daily amount
read that entity:

- **Dashboard hero and "Free to spend" breakdown.** The active budget,
  through `DashboardLoaded.activeSafeToSpend`. Two informational figures on
  the same entity come from the same division: `tomorrowIfNoMoreSpending`
  (the working sheet's "tomorrow" note) and `overTodayPerRemainingDay` (the
  hero's "about ₹X less on each of the next N days" line). Neither changes
  today's amount. The spending pace chart reads
  `DashboardLoaded.spendingPace`, built from discretionary spending only.
- **Other budgets today.** One tile per running budget. Amounts are never
  summed across budgets.
- **Morning notification.** `NotificationService.morningBody`. When the daily
  amount is 0, it explains why (over budget, overcommitted, or everything set
  aside).
- **Home-screen widget.** `HomeWidgetService.statusFor` maps the status to
  the string the native widgets parse:

  | Status | String |
  |---|---|
  | `overBudget`, `overcommitted` | `short:<shortfall>` |
  | `overDailyAllowance` | `over:<amount>` |
  | `spendingCarefully`, `budgetAtRisk` | `careful` |
  | `onTrack` | `on_track` |

  `no_budget` is written only when no budget is running.
- **Smart Insights.** `GetSmartInsightsUseCase` receives the active budget's
  entity. With it, the old bill-blind pace, projection and daily or weekly
  target insights are dropped. When the forecast is reliable, a forecast
  insight takes their place: a warning when the margin is negative, a
  positive note otherwise. Without a reliable forecast, "You're within this
  budget" appears only when the status is On track.

An active budget that has not started or has ended is a separate case
(`DashboardNotRunning`). It is shown from `GetSafeToSpendUseCase.call`'s
not-started or ended result, not as an error.

`DashboardBloc` computes "today" once per load and passes it to the summary,
the per-budget figures and the bills query.

## Bills and budgets

A bill can be linked to one budget (`bills.budget_id`, chosen as "Paid from"
in the bill form). Linking means *set this money aside from that budget until
it is paid*.

- **Linking.** "Not linked" is the default. The bill form only offers budgets
  that are not archived and have not ended, plus the current link, if any.
  The dashboard's **Link bills** sheet links bills in bulk through
  `LinkBillsToBudgetUseCase`. That use case links nothing if the budget is
  missing or archived, or if any bill's currency differs from the budget's.
- **Paying, "Mark paid & record expense".** This goes through
  `PayBillUseCase`, which runs one transaction that writes the payment
  record, advances the bill (or marks it paid) and creates the expense. The
  expense is recorded in:
  1. the linked budget, if it is running today, not archived and in the
     bill's currency;
  2. otherwise the active budget, under the same conditions;
  3. otherwise nowhere: the call fails with "No running budget in {CUR} to
     record this payment", and nothing is written.

  The expense gets `bill_id` only when it went to the linked budget and the
  occurrence was due on or before that budget's end. In that case, the money
  had been set aside, so paying it does not change today's amount. Any other
  payment is ordinary spending.
- **"Paid outside this budget".** This is the secondary action on a linked
  bill. It marks the bill paid without recording an expense. The confirmation
  says that this budget's safe-to-spend goes up.
- **Mark as unpaid.** This only applies to one-time bills, because a
  recurring bill advances instead. In one transaction, it deletes the newest
  payment record and the expenses with this bill's id dated on the day it was
  paid. The confirmation names those expenses. A plain payment expense
  (without `bill_id`) is kept.
- **Budget lifecycle.**
  - Deleting a budget unlinks its bills in the same transaction.
  - Archiving keeps the link. The bill is then no longer set aside anywhere,
    and running budgets in the same currency report it as "not linked".
  - "Start new budget period" moves the unpaid bills of the archived budget
    to the new one, with its kept-aside amount and savings goal, inside the
    reset transaction.

## Designed to be honest

- **Never pooled.** Each budget is evaluated on its own expenses, bills and
  set-asides. A bill linked to budget X never reduces budget Y.
- **Unavailable is not zero.** If the bills cannot be read, the breakdown
  says "Unavailable", a notice offers a retry, and the status is capped at
  "Spend carefully". The same cap applies when a linked bill is in another
  currency, because it is never converted and never deducted. The app never
  says "On track" about a figure that may be too optimistic.
- **Not set is not ₹0.** Kept aside and Savings goal show "Not set" when
  null.
- **Savings contributions are not tracked.** The app has no savings ledger or
  transfers. The whole savings goal is deducted for the entire period, and
  `savingsContributionsTracked` is always `false`. The app never shows
  progress toward the goal.
- **Never shown higher than it is.** Money is summed in integer units
  (`MoneyMath`). The domain keeps the exact quotient. The screens and the
  notification floor safe amounts to the currency's digits (OMR 7.6 shows as
  "ر.ع.7.600", never "8").
- **Calendar days.** Day counts compare UTC calendar dates, so a
  daylight-saving day is still one day.
- **The forecast is informational.** It uses only completed days and
  discretionary spending. It needs 3 completed days and at least one
  discretionary expense before today. It never changes today's amount.

## Statuses

The status is the first rule that matches:

1. Not started
2. Ended
3. Over budget (A < 0)
4. Overcommitted (bills and set-asides exceeded the balance before today's
   spending)
5. Over today's amount
6. At risk (the forecast runs out before the end)
7. Spend carefully
8. On track

Each status is shown with an icon and a text label, never colour alone. The
hero shows one explanation line, taken from the highest-priority reason.
Notices with actions cover bills that are unavailable, not linked or in
another currency.

## Data model (schema v8)

| Column | Meaning |
|---|---|
| `budgets.reserved_amount REAL NULL` | Kept aside; null = not set |
| `budgets.savings_target REAL NULL` | Savings goal; null = not set |
| `bills.budget_id TEXT NULL REFERENCES budgets(id)` | The budget the bill is paid from; indexed by `index_bills_budget` |
| `expenses.bill_id TEXT NULL` | Set only on a committed payment, as described above. It has no foreign key: the expense keeps its meaning after the bill is deleted. |

Rules for `expenses.bill_id`:

- It is cleared when the expense moves to another budget.
- Duplicate never copies it, and an ordinary edit never writes it.
- The integrity check does not flag a dangling `bill_id`.

Backup, JSON export and import, and restore all carry these fields. On
restore, a bill whose budget is not in the backup is unlinked.

## Tests that pin it

- `test/features/budget/domain/services/safe_to_spend_calculator_test.dart`:
  the formula, every phase and status, the precedence rules, rounding (OMR,
  JPY, 0.1 + 0.2, 1000 ÷ 3), leap years and DST, and the property
  "exhaustion date is null exactly when the margin is ≥ 0".
- `test/features/dashboard/domain/services/bill_occurrence_enumerator_test.dart`:
  paid and deleted bills, intervals, month-end dates matching repeated
  MarkBillPaid, overdue occurrences, other currencies, not linked.
- `test/features/dashboard/domain/usecases/get_safe_to_spend_usecase_test.dart`
  and `get_spending_targets_usecase_test.dart`: no double deduction after
  paying, independent budgets, unavailable bills.
- `test/features/bills/domain/usecases/pay_bill_usecase_test.dart`: atomicity,
  which budget is targeted, `bill_id` rules, and mark-unpaid.
- `test/integration/safe_spend_flows_test.dart`: link a bill and the daily
  amount drops; pay it and the amount is unchanged the same day; mark it
  unpaid and the amount is restored; reset relinks the bill.
- `test/integration/budget_flows_test.dart`: the figure holds steady through
  the day, drops the next day, and budgets never pool.
