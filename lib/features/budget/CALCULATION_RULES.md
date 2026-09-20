# Budget Calculation Rules

This document describes all formulas and business rules implemented by
`BudgetCalculationService`. All calculations are deterministic, offline, and
centralized — no screen or BLoC should duplicate this logic.

> **Note:** The codebase uses the field name `monthlyAmount` for historical
> reasons, but it represents the **total budget amount for the configured
> budget period**, which can span any custom date range (days, weeks, months,
> or longer).

---

## Remaining Days

```
Remaining Days = Budget End Date − Reference Date + 1
```

- **Today is always included.**
- **Minimum value is 1** (never 0) to prevent division errors.
- Reference date must fall within the budget period (start date ≤ today ≤ end date).

### Examples

| Today   | Budget End | Remaining Days |
|---------|------------|----------------|
| 15 Aug  | 25 Aug     | 11             |
| 25 Aug  | 25 Aug     | 1              |
| 10 Aug  | 10 Aug     | 1              |

---

## Days Passed

```
Days Passed = Reference Date − Budget Start Date + 1
```

Example: Budget starts 10 Aug, today is 15 Aug → 6 days passed (including today).

---

## Remaining Budget

```
Remaining Budget = Budget Amount − Total Spent
```

- Can be negative when over budget.
- Total spent is the sum of all expenses in the budget period.

---

## Daily Safe Spending (Daily Allowance)

```
Daily Allowance = Remaining Budget ÷ Remaining Days
```

### Example (early in budget period)

- Budget: ₹30,000 (30-day period)
- Spent: ₹0
- Remaining Days: 22
- **Allowance: ₹30,000 ÷ 22 = ₹1,363.64**

### Example (after spending)

- Remaining Budget: ₹29,200 (spent ₹800)
- Remaining Days: 22
- **Allowance: ₹29,200 ÷ 22 = ₹1,327.27**

---

## Midnight Rule

Unused daily allowance is **not removed** from the budget. At the start of each
new day, allowance is recalculated from the current remaining budget and
remaining days. Unspent money naturally increases the next day's allowance.

---

## Today's Overspending

```
Today Overspending = max(0, Today Spending − Daily Allowance)
```

Example: Allowance ₹1,428, Spent ₹2,000 → Overspent ₹572.

---

## Budget Utilization

```
Utilization = Total Spent ÷ Budget Amount   (ratio 0.0–1.0+)
Spending %  = Utilization × 100
Remaining % = (Remaining Budget ÷ Budget Amount) × 100
```

---

## Average Daily Spending

```
Average Daily = Total Spent ÷ Days Passed
```

- Days Passed minimum is 1 to avoid division by zero on day 1.

---

## Period-End Projection

```
Expected Period-End Spending = Average Daily × Days In Period
```

### Example

- Total Spent: ₹9,000
- Days Passed: 10
- Average: ₹900/day
- Period: 30 days
- **Projected: ₹27,000**

---

## Projected Savings / Overspending

```
If Projected > Budget  →  Overspending = Projected − Budget
If Projected < Budget  →  Savings      = Budget − Projected
Otherwise                →  0
```

---

## Budget Status

Configurable via `BudgetThresholds` (defaults shown):

| Status       | Condition (utilization ratio) |
|--------------|-------------------------------|
| underBudget  | < 80%                         |
| nearLimit    | 80% – 100%                    |
| overBudget   | > 100%                        |

---

## Error Handling

| Condition                          | Result                          |
|------------------------------------|---------------------------------|
| No budget for reference date       | `BudgetErrorType.notFound`      |
| Invalid date                       | `BudgetErrorType.invalidDate`   |
| Budget amount ≤ 0                  | `BudgetErrorType.invalidBudget` |
| Empty expense list                 | Total spent = 0 (valid)         |
| Reference date outside budget period | `BudgetErrorType.invalidDate` |

---

## Architecture

```
UI (Dashboard, Expenses, Reports, …)
        ↓
   BudgetBloc (no calculations)
        ↓
   Use Cases (single responsibility)
        ↓
   BudgetRepository (data access)
        ↓
   BudgetCalculationService (pure math)
```

All features must consume budget metrics through use cases or the BLoC — never
by reimplementing formulas locally.
