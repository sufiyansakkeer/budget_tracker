# Budget Calculation Rules

This document describes the formulas and business rules behind every budget
figure. Two pure, offline classes hold them, and no screen or BLoC repeats
their logic:

- `BudgetCalculationService` (`domain/services/budget_calculation_service.dart`)
  provides the primitives: day counts, the daily division, utilization, the
  budget summary and analytics.
- `SafeToSpendCalculator` (`domain/services/safe_to_spend_calculator.dart`)
  computes **Today's Safe Spending** for one budget once upcoming bills, money
  kept aside and the savings goal are protected. It also produces the
  safe-to-spend status, its reasons and the forecast. It uses the service for
  day counts and for the division.

`GetSafeToSpendUseCase` (`lib/features/dashboard/domain/usecases/`) gathers
the calculator's inputs from the database. Every surface that shows a daily
amount reads the entity it produces: the dashboard hero, "Other budgets
today", the morning notification, the home-screen widget and the onboarding
preview ("Today's Safe Spending starts at …", the draft budget on its first
day).

The morning notification is scheduled once per morning for the next 7
mornings, each computed for the day it fires (`referenceDate` = that day), so
a reminder scheduled in the evening carries tomorrow's amount. Every expense,
budget or bill change and every app start reschedules them; if the app is not
used for 7 days the reminders stop rather than repeat a stale amount.

> **Note:** The codebase uses the field name `monthlyAmount` for historical
> reasons, but it represents the **total budget amount for the configured
> budget period**, which can span any custom date range (days, weeks, months,
> or longer).

---

## Dates and day counts

Only calendar dates count; the time of day is ignored everywhere.

```
calendarDaysBetween(a, b) = days from the date of a to the date of b
                            (negative when b is earlier)
```

`BudgetCalculationService.calendarDaysBetween` compares
`DateTime.utc(year, month, day)` values. A local `difference().inDays` would
turn a 23-hour daylight-saving day into 0 days. With UTC dates, 8 Mar → 9 Mar
is 1 day in every time zone. `BudgetEntity.totalDays`, `daysElapsed` and
`daysRemaining` use the same arithmetic.

| Figure | Formula | Notes |
|---|---|---|
| Total days | `calendarDaysBetween(start, end) + 1` | A period stored as 1 Aug 12:00 → 31 Aug 00:00 is still 31 days |
| Days passed | `calendarDaysBetween(start, today) + 1` | **Today counts** |
| Remaining days | `calendarDaysBetween(today, end) + 1`, at least 1 | **Today counts**; never 0, so the division is safe |

The reference date must fall within the period (start ≤ today ≤ end).
Otherwise these methods throw. The safe-to-spend engine never calls them
outside the period (see [Before and after the period](#before-and-after-the-period)).

| Today  | Budget end | Remaining days |
|--------|------------|----------------|
| 15 Aug | 25 Aug     | 11             |
| 25 Aug | 25 Aug     | 1              |
| 10 Aug | 10 Aug     | 1              |

Example: a budget starts on 10 Aug and today is 15 Aug, so 6 days have
passed, today included.

Date stepping uses calendar arithmetic rather than `Duration`, so a
daylight-saving day still advances exactly one date:

- the exhaustion date is `DateTime(y, m, d + n)`;
- a weekly bill's next due date is `DateTime(y, m, d + 7 × interval)`.

---

## Remaining Budget (A)

```
A = Budget Amount − Period Spending
```

- **Period Spending** is the SQL `SUM` of the budget's expenses dated within
  the period, from the start date at 00:00 to the end date at 23:59:59.999
  (`BudgetRepository.getBudgetStatistics`).
- A is signed: it is negative when the budget is over.

The engine and the dashboard read Period Spending from SQL. The budget list,
its "Total remaining" and the budget picker show the stored
`budgets.remaining_amount` column, which holds the same A. Expense writes keep
it up to date; imports and restores, which write expenses straight to the
database, recompute it afterwards (`RecalculateRemainingAmountsUseCase`), and
app start runs the same repair once in the background.

"Total remaining" adds the running budgets' A **per currency**. Amounts in
different currencies are never added together or converted.

---

## Today's Safe Spending

### Inputs (per budget, per day)

| Input | Source |
|---|---|
| Budget amount, currency, start, end | The budget row |
| Period spending | SQL sum of the budget's expenses in the period |
| Today's spending | SQL sum of the budget's expenses dated today; 0 when today is outside the period |
| Committed spending (period, today) | The same sums, limited to expenses with `bill_id` set (`DashboardRepository.getCommittedSpending`) |
| Upcoming bill occurrences | `BillOccurrenceEnumerator.forBudget` over all bills (see [Which bills are deducted](#which-bills-are-deducted-b)) |
| Kept aside, savings goal | `budgets.reserved_amount`, `budgets.savings_target` (`null` = not set) |

"Today" is computed once per call, with the time of day stripped, and the
same value is used for every budget in that call.

### Formula (running period)

```
A   = Budget Amount − Period Spending                       (signed)
B   = Σ amounts of the upcoming bill occurrences            (deduplicated)
C   = max(0, Kept Aside ?? 0)
D   = max(0, Savings Goal ?? 0)        contributions are not tracked, so the whole goal

Raw Spendable  = A − B − C − D                               (signed, never clamped)
Free to Spend  = max(0, Raw Spendable)
Shortfall      = max(0, −Raw Spendable)

Today's Discretionary = Today's Spending − Committed Spending Today
S0 (spendable at the start of today) = Raw Spendable + Today's Discretionary

Today's Safe Spending = max(0, S0 ÷ Remaining Days)
                      = max(0, (Raw Spendable + Today's Discretionary) ÷ Remaining Days)

Left Today = max(0, Today's Safe Spending − Today's Discretionary)
Over Today = max(0, Today's Discretionary − Today's Safe Spending)
```

The division is `BudgetCalculationService.calculateTodaySafeSpending`, called
with `remainingBudget: Raw Spendable` and `todaySpending: Today's
Discretionary`. **No other code divides a remaining amount by remaining
days.**

Kept-aside and savings values below 0 can only come from corrupt data, so they
are clamped to 0 and never add money.

### Why today's discretionary spending is added back

The figure is a *limit for today*. Without the add-back it would shrink after
every purchase: spend ₹300 of a ₹1,000 limit and the limit itself would drop
to about ₹986, which made the number feel broken. With the add-back the limit
stays fixed for the day, and today's spending is compared against it ("₹300
spent of ₹1,000"). Tomorrow the limit is recomputed from what is genuinely
left.

### Why committed payments are not added back

A **committed** expense is one with `bill_id` set. It settled a bill
occurrence that this same budget had already set aside in B. Paying that bill
moves the amount out of B and into Period Spending, so Raw Spendable does not
change. Today's Discretionary excludes it, so S0 and Today's Safe Spending do
not change either: paying a planned bill does not use up today's amount.

Only `PayBillUseCase` writes `bill_id`, and only when both of these hold:

- the payment is recorded in the budget the bill is linked to;
- the occurrence's due date is on or before that budget's end.

Every other payment is plain (discretionary) spending. `bill_id` is cleared
when the expense moves to another budget, and it is never copied by Duplicate
or written by an edit.

### Baseline and allowance reduction

```
Baseline Daily      = max(0, (A + Today's Discretionary) ÷ Remaining Days)    (B = C = D = 0)
Allowance Reduction = max(0, Baseline Daily − Today's Safe Spending)
```

This is how much the deductions lower today's amount. With no bills, nothing
kept aside and no savings goal, Today's Safe Spending equals the budget
summary's `dailySafeSpending` (within 1e-9). The parity tests in
`dashboard_budget_edit_test.dart` and `budget_amount_change_test.dart` assert
this.

### Worked example

A ₹30,000 budget from 1 to 30 Aug 2026. Today is 9 Aug: 9 days have passed
and 22 remain. ₹6,000 has been spent, ₹300 of it today. An electricity bill
of ₹2,200, linked to this budget, is due on 15 Aug. ₹1,000 is kept aside and
the savings goal is ₹2,000.

| Quantity | Value |
|---|---|
| A, remaining in budget | 30,000 − 6,000 = ₹24,000 |
| B, bills due | ₹2,200 |
| C, kept aside | ₹1,000 |
| D, savings goal | ₹2,000 |
| Raw Spendable = Free to Spend | ₹18,800 |
| Today's Safe Spending | (18,800 + 300) ÷ 22 = ₹868.18 |
| Left today | ₹568.18 |
| Baseline (no deductions) | (24,000 + 300) ÷ 22 = ₹1,104.55 |
| Allowance reduction | ₹236.36 |

Now suppose the bill is paid today with "Mark paid & record expense". Period
Spending becomes ₹8,200, Today's Spending ₹2,500 and Committed Today ₹2,200.
B becomes 0 and A becomes ₹21,800, so Raw Spendable stays ₹18,800. Today's
Discretionary stays ₹300, so **Today's Safe Spending stays ₹868.18**. Only
the baseline changes, to ₹1,004.55, because it ignores B.

---

## Which bills are deducted (B)

`BillOccurrenceEnumerator` (`lib/features/dashboard/domain/services/`) is
pure and has no clock. For one budget:

- **Only unpaid bills count.** A paid one-time bill is finished. A recurring
  bill is advanced when it is paid, so an occurrence that has been paid is
  never enumerated. A deleted bill is gone, because bills have no "cancelled"
  state.
- **Occurrences.** The first occurrence is the stored due date. Each next one
  comes from applying the same step `MarkBillPaid` stores
  (`bill.copyWith(dueDate: d).nextDueDate`, with the interval honoured), while
  the date is ≤ the budget's end. The step only repeats when `isRecurring` is
  true and `recurrenceType` is not `none`. A step that does not advance the
  date stops the loop, and each bill is capped at 1,000 occurrences.
- **Running budget.** Every occurrence of a bill linked to the budget, up to
  its end, is deducted. Overdue occurrences from before today, or before the
  start, are included and flagged `isOverdue`: they are still owed and will be
  paid from this budget.
- **Budget not started or ended.** Only the occurrences inside
  [start, end] are deducted.
- **Different currency.** A linked bill in another currency is never deducted.
  It is disclosed instead (`currencyExcluded`: the number of bills and the
  totals per currency).
- **Deduplication.** The engine deduplicates occurrences by (bill id, due
  date) and sorts them by due date. `SafeToSpendEntity.commitments` is exactly
  the list that was deducted.

**Not linked** (disclosed, never deducted): these are bills in the budget's
currency that are not linked to this budget, and that have an occurrence
between today (or the start, if later) and the period end that no budget sets
aside. An occurrence is not set aside when the bill has no link, or when the
budget it is linked to:

- is deleted;
- is archived;
- or does not contain that occurrence.

"Contains" means:

- if that budget is running, the occurrence is due on or before its end;
- otherwise, the occurrence is inside its [start, end].

`unlinked.count` counts bills and `unlinked.total` sums the occurrences. The
dashboard's "Link bills" sheet uses the same rule
(`BillOccurrenceEnumerator.billsNotSetAside`).

---

## Before and after the period

The engine compares calendar dates and never calls the service's day-count
methods outside the period.

| Phase | Condition | Results |
|---|---|---|
| Not started | today < start | Days passed 0, remaining days = total days, `daysUntilStart` = days until the start. Today's Safe Spending, Left/Over today and the baseline are 0, and today's spending is ignored. B lists the occurrences inside the period. No forecast. |
| Running | start ≤ today ≤ end | Everything above |
| Ended | today > end | Days passed = total days, remaining days 0. The daily figures are 0. A is the final balance. No forecast. |

---

## Status

`SafeToSpendStatus` is the first rule that matches. The defaults below come
from `SafeToSpendThresholds`.

| # | Status | Label | Condition |
|---|---|---|---|
| 1 | `notStarted` | Not started | today < start |
| 2 | `periodEnded` | Ended | today > end |
| 3 | `overBudget` | Over budget | A < 0 |
| 4 | `overcommitted` | Overcommitted | S0 < 0: bills and money set aside exceeded the balance **before** today's discretionary spending. Today's spending alone can never cause this. |
| 5 | `overDailyAllowance` | Over today's amount | Today's Discretionary > Today's Safe Spending |
| 6 | `budgetAtRisk` | At risk | The forecast is reliable and the projected margin is < 0 |
| 7 | `spendingCarefully` | Spend carefully | Any of the conditions listed below |
| 8 | `onTrack` | On track | Otherwise |

`spendingCarefully` applies when any of these is true:

- S0 = 0;
- Today's Safe Spending > 0 and Today's Discretionary ≥ `carefulDailyRatio` (0.8) × Today's Safe Spending;
- the forecast is reliable and the projected margin < `carefulMarginRatio` (0.10) × S0;
- the bills could not be read;
- a linked bill is in another currency.

Notes:

- **Rule 5 is decided on integer units.** When S0 > 0, it is
  `discretionary × remaining days > S0`. When S0 ≤ 0, it is any
  discretionary spending above 0. So it never depends on how the quotient
  rounds.
- **Rule 7 tolerance.** The 0.8 comparison allows a tolerance of 1e-6 units.
- **Missing data caps the status.** Unread bills and bills excluded for their
  currency cap the status at "Spend carefully". The app never says "On track"
  about a figure that may be optimistic. Bills that are only *not linked* are
  disclosed but do not cap the status.

---

## Reasons

The engine emits `SafeToSpendReason`s in the order the hero explains them. The
first one is `topReason`.

| Order | Reason | When |
|---|---|---|
| 1 | `BillsUnavailableReason` | The bills could not be read |
| 2 | `OverBudgetByReason(−A)` | A < 0 |
| 3 | `OvercommittedByReason(−raw)` (the shortfall, as the breakdown shows it) | S0 < 0 and A ≥ 0 |
| 4 | `OverTodayReason(amount)` | Rule 5 of the status |
| 5 | `AtRiskReason(averageDaily, deficit)` | Rule 6 of the status |
| 6 | `BillsNotLinkedReason(count, total)` | Bills in the budget's currency that no budget sets aside |
| 7 | `BillsCurrencyExcludedReason(count, totals)` | Linked bills in another currency |
| 8 | `NothingFreeToSpendReason` | Raw ≤ 0, A ≥ 0 and S0 ≥ 0 |
| 9 | `AllowanceReducedReason(amount, bills, reserved?, savings?)` | Baseline > Today's Safe Spending |
| 10 | `BillPaymentsTodayReason(amount)` | Committed Spending Today > 0 |
| 11 | `BillsDueReason(total, count, nextDue)` | At least one occurrence is deducted |
| 12 | `ForecastInsufficientReason(daysNeeded, hasAnyExpense)` | The forecast is not reliable |

Before the start, the reasons are limited to 1, 2, 6, 7 and 11. After the
end, only 2 is kept.

---

## Forecast

The forecast is informational: it never changes today's amount. It only uses
**completed days**, because today is still in progress, and only
**discretionary** spending, because bills are already in B.

```
Completed Days           = Days Passed − 1
Discretionary To Date    = Period Spending − Committed Spending In Period
Discretionary Completed  = Discretionary To Date − Today's Discretionary

Reliable ⟺ Completed Days ≥ minForecastDays (3)  and  Discretionary Completed > 0

Average Daily      = Discretionary Completed ÷ Completed Days
Today Projected    = max(Today's Discretionary, Average Daily)
Future Spend       = (Today Projected − Today's Discretionary) + Average Daily × (Remaining Days − 1)

Projected Discretionary Spending = Discretionary To Date + Future Spend
Projected Period Spending        = Committed Spending In Period + B + Projected Discretionary Spending
Projected End Balance            = Budget Amount − Projected Period Spending
Projected Margin                 = Raw Spendable − Future Spend
                                 = Projected End Balance − C − D
Pace Ratio                       = Average Daily ÷ Today's Safe Spending   (null when that is 0)
```

The engine multiplies every intermediate by Completed Days, so the average is
never rounded before it is used.

### Exhaustion date

The exhaustion date is *the first day the free-to-spend money runs out at the
current pace*.

```
if Projected Margin ≥ 0:  no exhaustion date
else:
  Left After Today = Raw Spendable − (Today Projected − Today's Discretionary)
  if Left After Today < 0:  today
  else:                     today + 1 + floor(Left After Today ÷ Average Daily) days
```

- The exhaustion date is null **exactly** when the margin is ≥ 0.
- When the margin is negative, the date always falls within [today, end].
- The date is computed with calendar arithmetic.

### Insufficient history

```
Days Needed = minForecastDays − Completed Days     when Completed Days < minForecastDays
            = 1    when there are enough days and only today has discretionary spending
            = 0    when there is no discretionary spending at all
Has Any Expense = Discretionary To Date > 0
```

Under the "Forecast" heading the dashboard shows "Ready after *n* more days
of spending" when Days Needed > 0. Otherwise it shows "Ready after your first
expense in this budget."

### Example

This uses the worked example's budget, but ₹13,000 was spent on the 8
completed days and ₹300 today, so A = ₹16,700 and Raw Spendable = ₹11,500:

- Average Daily = 13,000 ÷ 8 = ₹1,625, and Today Projected = ₹1,625.
- Future Spend = (1,625 − 300) + 1,625 × 21 = ₹35,450.
- Projected Margin = 11,500 − 35,450 = −₹23,950, so the status is **At risk**.
- Left After Today = 11,500 − 1,325 = ₹10,175, which gives an exhaustion date
  of 9 Aug + 1 + floor(10,175 ÷ 1,625) = **16 Aug**.

---

## Tomorrow (informational)

Two figures help the user see how today's choice moves tomorrow. Neither
changes today's amount. Both use the same single division as today's amount
(`calculateTodaySafeSpending`), over the days left *after* today:

```
Tomorrow if nothing more is spent today = max(0, Raw Spendable ÷ (Remaining Days − 1))
Overspend per later day                 = Over Today ÷ (Remaining Days − 1)
```

- **Why Raw Spendable.** Tomorrow starts with today's discretionary spending
  already in Period Spending, and a set-aside bill payment never moves Raw
  Spendable. So if nothing more is spent today, and no bill, kept-aside amount
  or savings goal changes, tomorrow's amount is exactly this. The UI says
  "about" because those inputs can change.
- **Why the overspend spreads.** Spending exactly today's amount would leave
  S0 − Today's Safe Spending for the later days; spending more leaves
  Over Today less, shared over Remaining Days − 1 days. Shown only while
  tomorrow's amount is still above 0, where the statement is exact.
- **Null** on the last day of the period (there is no tomorrow in it) and
  outside the running period.

Fields: `SafeToSpendEntity.tomorrowIfNoMoreSpending` and
`overTodayPerRemainingDay`.

## Spending pace (informational)

The dashboard compares discretionary spending so far with an even pace
through the period (`SpendingPaceBuilder`, `GetSpendingPaceUseCase`):

```
Planned discretionary money = Raw Spendable + Discretionary Spent So Far
                            = Budget − Bill payments made − B − C − D
Planned to date             = Planned × Days Passed ÷ Total Days   (floored)
Actual to date              = Σ discretionary spending, start → today
Ahead of plan               = Actual to date − Planned to date
```

- Discretionary means expenses without a `bill_id`, the same split the
  engine uses. Days are calendar days.
- It is a view as of today: linking a bill or setting money aside lowers the
  planned line for the whole period.
- Shown once three days have passed, something has been spent and the
  planned amount is above 0 (`SpendingPace.isMeaningful`).

## Money arithmetic and rounding

- **Integer units.** `MoneyMath` (`lib/core/currency/money_math.dart`)
  converts every input amount to integer units **once**. The scale is
  10^max(ISO digits, 2): OMR 1000, INR 100, JPY 100. JPY uses 100 because the
  forms accept two decimals for every currency. Rounding is half away from
  zero, on the decimal value, so 0.145 becomes 15 units. Every sum, difference
  and comparison runs on the integers; only the outputs go back to doubles.
  So 0.1 + 0.2 is exactly 0.3.
- **Range.** Every amount field and use case (budget, expense, bill,
  change amount; kept aside and savings are capped by the budget amount)
  accepts amounts below `MoneyMath.maxAmount` (1,000,000,000,000).
  `toUnits` refuses more than 2^53 units with an `ArgumentError`. Products of
  units with day counts (the forecast, the over-today test) run in `BigInt`,
  so nothing wraps on a long period. A budget the engine cannot evaluate
  (e.g. imported data beyond the limit) is left out of
  `GetSafeToSpendUseCase.callForBudgets`, so it never clears the other
  budgets' figures.
- **The domain never floors.** Today's Safe Spending is the exact
  `calculateTodaySafeSpending` quotient. For example, ₹1,000 ÷ 3 is
  333.333…
- **Display floors the "safe" amounts.** Today's Safe Spending, Left today,
  Free to spend, the other-budget amount and the morning notification amount
  go through `CurrencyFormatter.floorForDisplay` / `formatFloored`. The value
  is floored to the currency's ISO digits; a value within 1e-6 of a minor unit
  is snapped to it first.
  - It is shown with those digits when it has a fraction at that precision,
    and with 0 otherwise.
  - Examples: OMR 7.6 → "⃄ 7.600" (never "8"); ₹1,000 ÷ 3 → ₹333.33;
    ₹1,000.004 → ₹1,000; JPY 99.9 → ¥99.
  - A safe amount is never shown higher than it is.
- **Other amounts** (bills, kept aside, projections) are rounded to the minor
  unit, and decimals are shown only when there is a fraction.
- **Home-screen widget.** The status writes `short:` and `over:` amounts
  rounded **up** to whole units, so a shortfall is never understated. The
  daily amount is written with 2 decimals, and the native widget formats it
  itself, without flooring.

---

## Unavailable, not set, and zero

These are different states, and both the entity and the UI keep them apart:

| State | Entity | Shown as |
|---|---|---|
| Bills could not be read | `commitments` empty, `commitmentsAvailable == false`, B = 0, `BillsUnavailableReason` first, status capped | "Unavailable" in the breakdown, with a retry notice. Never ₹0. |
| No bills due | `commitments` empty, `commitmentsAvailable == true`, B = 0 | "No bills due this period" with ₹0 |
| Kept aside / savings goal not set | `reservedAmount == null` / `savingsTarget == null` | "Not set" |
| Kept aside / savings goal set to 0 | `0.0` | ₹0 |
| Forecast not ready | `forecast.isReliable == false` with `daysNeeded` | "Ready after *n* more days of spending" |
| Budget not running | `forecast == null`, daily figures 0 | The not-started or ended card, not "₹0 today" |

The app has no savings ledger. `savingsContributionsTracked` is always
`false`, and the remaining savings goal is the whole goal. That is a
documented assumption; the app never shows progress toward the goal.

---

## Midnight Rule

Unused daily allowance is **not removed** from the budget. At the start of
each new day, the allowance is recalculated from the current Raw Spendable and
Remaining Days. Unspent money therefore raises the next day's allowance, and
overspending lowers it.

---

## Today's Overspending

```
Over Today = max(0, Today's Discretionary − Today's Safe Spending)
```

Example: the allowance is ₹1,428 and ₹2,000 of discretionary spending happened
today, so Over Today is ₹572.

The budget summary's `todayOverspending` (`calculateTodayOverspending`)
applies the same formula to all of today's spending, against the summary's
`dailySafeSpending`, which has no deductions.

---

## Budget summary figures

`BudgetCalculationService.buildSummary` / `buildAnalytics` produce the budget
summary. Three things use it:

- the dashboard's budget overview;
- `BudgetBloc`;
- the budget-level Smart Insights.

Reports have their own analytics service.

These figures know nothing about bills, kept-aside money or the savings goal.
When the active budget has a safe-to-spend result, the insights drop the
summary's pace, projection and today-overspending messages. The dashboard's
forecast is the safe-to-spend forecast above, not this projection.

### Utilization

```
Utilization = Total Spent ÷ Budget Amount   (ratio 0.0–1.0+)
Spending %  = Utilization × 100
Remaining % = (Remaining Budget ÷ Budget Amount) × 100
```

### Daily safe spending (summary)

```
dailySafeSpending = (Remaining Budget + Today's Spending) ÷ Remaining Days
```

This matches the engine with B = C = D = 0 and no committed payments today.

### Average daily spending

```
Average Daily = Total Spent ÷ Days Passed      (Days Passed at least 1)
```

### Period-end projection

```
Expected Period-End Spending = Average Daily × Days In Period
```

Example: ₹9,000 spent over the first 10 days is ₹900 a day, so a 30-day
period projects ₹27,000.

### Projected savings / overspending

```
If Projected > Budget  →  Overspending = Projected − Budget
If Projected < Budget  →  Savings      = Budget − Projected
Otherwise              →  0
```

### Budget status

Configurable via `BudgetThresholds` (defaults shown):

| Status       | Condition (utilization ratio) |
|--------------|-------------------------------|
| underBudget  | < 80%                         |
| nearLimit    | 80% – 100%                    |
| overBudget   | > 100%                        |

---

## Error Handling

| Condition                            | Result                          |
|--------------------------------------|---------------------------------|
| No budget for reference date         | `BudgetErrorType.notFound`      |
| Invalid date                         | `BudgetErrorType.invalidDate`   |
| Budget amount ≤ 0                    | `BudgetErrorType.invalidBudget` |
| Empty expense list                   | Total spent = 0 (valid)         |
| Reference date outside budget period | `BudgetErrorType.invalidDate`   |

When the active budget's summary fails with `invalidDate` (the budget is not
running today), the dashboard does not show an error. It asks
`GetSafeToSpendUseCase.call` for the not-started or ended result and shows
that instead (`DashboardNotRunning`).

---

## Architecture

```
UI (Dashboard, notifications, home-screen widget, …)
        ↓
   BLoCs (no calculations)
        ↓
   Use Cases: GetSafeToSpendUseCase, GetSpendingTargetsUseCase, …
        ↓                                   ↓
   Repositories (SQL sums, bills)    BillOccurrenceEnumerator (pure)
        ↓
   SafeToSpendCalculator (pure) → BudgetCalculationService (pure math)
```

All features must consume budget metrics through use cases or the BLoC,
never by reimplementing formulas locally.
