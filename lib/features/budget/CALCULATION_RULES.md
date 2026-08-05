# Budget Calculation Rules

This document describes all formulas and business rules implemented by
`BudgetCalculationService`. All calculations are deterministic, offline, and
centralized — no screen or BLoC should duplicate this logic.

---

## Remaining Days

```
Remaining Days = Days In Month − Day Of Month + 1
```

- **Today is always included.**
- **Minimum value is 1** (never 0) to prevent division errors.
- Reference date must fall within the budget month/year.

### Examples

| Today   | Month Days | Remaining Days |
|---------|------------|----------------|
| 10 Aug  | 31         | 22             |
| 31 Aug  | 31         | 1              |
| 29 Feb  | 29 (leap)  | 1              |

---

## Days Passed

```
Days Passed = Day Of Month
```

Example: 10 August → 10 days passed (including today).

---

## Remaining Budget

```
Remaining Budget = Monthly Amount − Total Spent
```

- Can be negative when over budget.
- Total spent is the sum of all expenses in the budget month.

---

## Daily Safe Spending (Daily Allowance)

```
Daily Allowance = Remaining Budget ÷ Remaining Days
```

### Example (start of month)

- Budget: ₹30,000
- Spent: ₹0
- Date: 10 August (31-day month)
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
Utilization = Total Spent ÷ Monthly Amount   (ratio 0.0–1.0+)
Spending %  = Utilization × 100
Remaining % = (Remaining Budget ÷ Monthly Amount) × 100
```

---

## Average Daily Spending

```
Average Daily = Total Spent ÷ Days Passed
```

- Days Passed minimum is 1 to avoid division by zero on day 1.

---

## Month-End Projection

```
Expected Month-End Spending = Average Daily × Days In Month
```

### Example

- Total Spent: ₹9,000
- Days Passed: 10
- Average: ₹900/day
- 30-day month
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

| Condition                    | Result                          |
|------------------------------|---------------------------------|
| No budget for current month  | `BudgetErrorType.notFound`      |
| Invalid month/year           | `BudgetErrorType.invalidDate`   |
| Monthly amount ≤ 0           | `BudgetErrorType.invalidBudget` |
| Empty expense list           | Total spent = 0 (valid)         |
| Reference date outside month | `BudgetErrorType.invalidDate`   |

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
