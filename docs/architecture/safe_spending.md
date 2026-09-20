# Today's Safe Spending

The number on the dashboard hero, in the morning notification and on the
home-screen widget. It answers: *if I keep to plan, what can I spend today?*

## The formula

```
Today's Safe Spending = (Remaining Budget + Spent Today) ÷ Remaining Days
```

- **Remaining Budget** = budget amount − everything spent in this budget's
  period.
- **Spent Today** = expenses recorded against this budget, dated today.
- **Remaining Days** = end date − today + 1 (today counts), floored at 1.

It lives in exactly one place:
`BudgetCalculationService.calculateTodaySafeSpending`
(`lib/features/budget/domain/services/budget_calculation_service.dart`).
The dashboard, the per-budget limits, `CalculateDailyAllowanceUseCase`, the
notification body and the home-screen widget all call it. No other code
divides a remaining amount by remaining days.

## Why today's spending is added back

Without the add-back the figure would shrink with every purchase: spend ₹300
against a ₹1,000 limit and the *limit itself* would drop to about ₹986, which
reads as broken. With the add-back the limit is fixed for the day and today's
expenses are measured against it — "₹300 spent of ₹1,000, ₹700 left today".
Tomorrow the limit is recomputed from what is genuinely left, so overspending
today does lower tomorrow.

## The midnight rule

Unspent allowance is not banked or removed. At the start of each day the
figure is recomputed from the current remaining amount and remaining days, so
an underspent day quietly raises the next day's number.

## Worked example

A ₹30,000 budget over 30 days, on day 9 with ₹8,000 already spent and ₹800 of
that spent today:

| Quantity | Value |
| --- | --- |
| Remaining budget | ₹22,000 |
| Remaining days (incl. today) | 22 |
| Today's Safe Spending | (22,000 + 800) ÷ 22 = ₹1,036.36 |
| Spent today | ₹800 |
| Left today | ₹236.36 |

## Related figures

Derived by the same service, never by a screen:

- **Average daily spending** = total spent ÷ days passed.
- **Projected period-end spending** = average daily × days in period.
- **Projected savings / overspending** = the difference between that
  projection and the budget amount.
- **Today's overspending** = max(0, spent today − today's safe spending).
- **Status** — under budget, near limit or over budget — from utilisation
  against `BudgetThresholds` (0.80 and 1.0 by default).

Full rules and edge cases:
[`lib/features/budget/CALCULATION_RULES.md`](../../lib/features/budget/CALCULATION_RULES.md).

## Tests that pin it

- `test/features/budget/domain/services/budget_calculation_service_test.dart`
- `test/features/dashboard/domain/usecases/get_spending_targets_usecase_test.dart`
- `test/integration/budget_flows_test.dart` — the figure holds steady as a day
  is spent, and drops the next day.
