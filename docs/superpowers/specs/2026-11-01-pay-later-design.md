# Pay Later — design

Date: 2026-11-01. Status: approved by the user 2026-11-01.

## 1. Intent

The user eats at a cafeteria that keeps a running tab. Each meal is consumed now
and paid for every 14 or 21 days, in full or in part. Today Monivo can record the
meal as an expense, but it cannot answer "how much do I owe the cafeteria, for
what, and what did my last payment cover?".

Pay Later adds **tabs**: accounts with a person, shop or business that let you
buy now and settle later (cafeteria, grocery credit, restaurant tab, local shop,
money owed to a friend). It tracks what you owe on each tab, the meals and
purchases behind that amount, and every payment you make against it.

### Goals

- Multiple independent tabs, each with its own owed balance, purchase list and
  payment history.
- Record a purchase on a tab from the existing Add Expense flow; the purchase is
  an ordinary Monivo expense, counted once.
- Full, partial and multiple payments; oldest purchases are paid first by
  default, with the option to choose specific purchases.
- Owed balance is always right, carries forward forever, never resets at a
  period boundary.
- Settle rhythm per tab (on demand, every N days, monthly on a day, or a date
  you set), with optional reminders that never record anything.
- Overview across tabs plus per-tab detail and simple charts.

### Non-goals

- **Scheduled obligations** (rent, internet, subscriptions, service charges).
  These stay in Bills. Pay Later has no recurring-entry generator. (Agreed with
  the user 2026-11-01.)
- Multi-item purchases as one record. Each item is its own expense; the note
  field covers "2 coffees + sandwich".
- Interest, fees, credit limits, shared tabs, money other people owe you.
- Currency conversion between a tab and a budget.

### Anti-goals (would make this a failure even if it works)

- A payment that lowers a budget, appears in expense history, or is counted in
  reports/Safe-to-Spend. The money was counted at the meal.
- A meal counted twice (once as an expense, once as a "payable").
- An edit or delete that silently changes what was already paid.
- Any change in behaviour for ordinary expenses, Bills, budgets,
  Safe-to-Spend, reports, history, the home widget, backup or CSV export for a
  user who never creates a tab.
- A cafeteria-only feature: meal names or meal types built into the model.

## 2. Decisions made with the user

1. **A purchase on a tab is an ordinary expense plus a link to the tab.** It is
   recorded once, in the budget that covers its date, and appears everywhere
   expenses already appear. The budget drops when you eat, not when you pay.
2. **A payment is a settlement, not an expense.** It never touches a budget.
3. **Owed = purchases on the tab − payment money applied to them.** Partial
   payments leave the rest owing; nothing resets at period boundaries.
4. **Payments can't exceed what the tab owes** at the time they are recorded.
5. **Money uses Monivo's existing representation** (REAL columns, arithmetic and
   rounding through the existing `MoneyMath` helpers at the currency's decimals),
   so tab totals match budget totals exactly.
6. **Bills is not duplicated.** Recurring obligations stay there.
7. **Entry point is the existing Add Expense form.** A "Pay later" choice reveals
   a tab selector; saving writes the expense and its tab link in one
   transaction. Each tab also has an "Add to tab" action that opens the same
   form with that tab preselected.
8. Editing/deleting linked expenses is allowed but reconciles payments safely
   and never silently (section 5).
9. Historical purchases are allowed under the existing rule: the date must fall
   inside the chosen budget's period.
10. A tab has one currency; every linked expense must be in a budget of that
    currency.
11. Settlement reminders are optional and only remind.

## 3. Data model (schema v8 → v9)

Four new tables. **No existing table changes.** Existing rows are untouched by
the migration.

### `pay_later_accounts` (a tab)

| column | type | notes |
|---|---|---|
| id | text PK | uuid |
| name | text, 1–100 | "Campus cafeteria" |
| category | text | one of `food_dining`, `groceries`, `shopping`, `personal`, `other` (stored as key; drives icon only) |
| currency | text | ISO code; fixed once the tab has purchases or payments |
| note | text? | |
| contact | text? | free text: phone, person, location |
| default_category_id | text? | expense category preselected when adding to this tab; no FK (category may be archived/deleted) |
| rhythm | text | `on_demand`, `every_days`, `monthly_day`, `manual_date` |
| rhythm_days | int? | for `every_days` (7/14/21/30 presets or custom 1–365) |
| rhythm_day_of_month | int? | 1–31 for `monthly_day`; clamped to the month's length |
| rhythm_anchor | datetime? | first day of the first period (`every_days`) |
| next_settle_date | datetime? | for `manual_date` only |
| reminder_enabled | bool, default false | |
| reminder_offset_days | int, default 0 | 0 = on the settle-up day |
| is_archived | bool, default false | |
| created_at / updated_at | datetime | |

**Tab category list is deliberately not the "Accommodation/Utilities/Services"
set from the original brief**: those are Bills territory. Category is
presentation only (icon + grouping); no behaviour depends on it.

### `pay_later_entries` (the link: an expense is on a tab)

| column | type | notes |
|---|---|---|
| expense_id | text PK, FK → expenses.id ON DELETE CASCADE | one tab per expense at most |
| account_id | text FK → pay_later_accounts.id | |
| created_at | datetime | |

Index on `account_id`. The amount, date, note and category live on the expense;
nothing is copied.

### `pay_later_payments`

| column | type | notes |
|---|---|---|
| id | text PK | |
| account_id | text FK → pay_later_accounts.id | |
| amount | real | > 0, in the tab's currency |
| paid_date | datetime | date the money changed hands (may be in the past) |
| note | text? | |
| created_at / updated_at | datetime | |

Index on `(account_id, paid_date)`.

### `pay_later_allocations`

| column | type | notes |
|---|---|---|
| id | text PK | |
| payment_id | text FK → pay_later_payments.id ON DELETE CASCADE | |
| expense_id | text FK → pay_later_entries.expense_id ON DELETE CASCADE | |
| amount | real | > 0 |
| is_manual | bool | user chose this purchase explicitly |
| created_at | datetime | |

Unique `(payment_id, expense_id)`; indexes on `payment_id` and `expense_id`.

Foreign keys are already enforced (`PRAGMA foreign_keys = ON`). Cascades mean a
deleted expense takes its link and allocations with it; the **payment always
survives**, and reconciliation (section 5) puts its money back to work.

### Derived values (never stored)

- `paid(expense)` = Σ allocations for it. `owes(expense)` = amount − paid.
- Status: unpaid (paid = 0), partly paid, paid (owes = 0).
- `applied(payment)` = Σ its allocations. `unapplied(payment)` = amount − applied.
- Tab `owed` = Σ owes over its purchases. Tab `credit` = Σ unapplied over its
  payments.
- **Invariant after every write:** `owed == 0 || credit == 0` (reconcile applies
  credit to anything still owing). Displayed balance = owed, or "In credit X".
- All sums via `MoneyMath` at the tab currency's decimals; a value within half a
  minor unit of zero is zero.

## 4. Settle rhythm, periods and dates

Four dates are kept distinct:

1. **Purchase date** — the expense's date.
2. **Period** — the stretch of days a purchase is grouped into.
3. **Settle-up day** — when payment is expected for a period.
4. **Payment date** — when money actually changed hands (`paid_date`).

Rules (calendar days via `lib/core/dates/calendar_dates.dart`, never `Duration`):

- `every_days(N)`: periods are `[anchor + kN, anchor + (k+1)N − 1]` for every
  integer k (also before the anchor, so old purchases get a period). Settle-up
  day = first day of the next period.
- `monthly_day(D)`: a period runs from day D of one month to the day before day
  D of the next (D clamped to month length). Settle-up day = day D at its end.
- `manual_date`: the current period runs from `rhythm_anchor` to the day before
  `next_settle_date`; settle-up day = `next_settle_date`. Purchases dated before
  `rhythm_anchor` form one "earlier" period whose settle-up day is
  `rhythm_anchor` (so anything still owing there is overdue). When the user sets
  a new date after the old one has passed, `rhythm_anchor` becomes the old date.
  Purchases dated on or after a passed `next_settle_date` with no new date set
  belong to an open period with no settle-up day (not overdue, no reminder) and
  the tab shows "Set your next settle-up date". Nothing advances automatically.
  (No extra column: `rhythm_anchor` is reused.)
- `on_demand`: no periods, no settle-up day, never overdue.
- **Overdue amount** = Σ owes over purchases whose period's settle-up day is
  before today. Overdue is a display state only.
- **Next settle-up** = the settle-up day of the current period (on_demand:
  none).
- Changing a tab's rhythm regroups history; nothing stored depends on periods.
- Periods are a view. A purchase is never blocked because an earlier period is
  unpaid, and payments are never tied to a period.

## 5. Payments, allocation and reconciliation

All writes below run in one database transaction and finish with
`reconcile(tab)`.

**Record payment** (amount, date, note, optional chosen purchases):

- Reject amount ≤ 0, or amount > tab owed (after rounding).
- Default (FIFO): apply to purchases on this tab with owes > 0, ordered by
  purchase date, then time, then created_at; each allocation = min(remaining,
  owes).
- Manual: the user picks purchases; amount defaults to their total owed.
  Allocate to the picked ones in FIFO order among them, never above each one's
  owes. Any amount left over then goes FIFO to the rest (rule: a payment never
  sits unapplied while something is owed). Manual allocations get
  `is_manual = true`.
- "Settle all" = amount prefilled to owed.

**Edit payment:**

- Amount down: trim its allocations, newest purchase first.
- Amount up: rejected if new amount > owed + this payment's current applied
  amount; otherwise the extra is applied FIFO.
- Date/note only: no allocation change.

**Delete payment:** allocations cascade away; those purchases owe again.
Confirmation names the amount that will be owed again.

**Edit a purchase (the expense) on a tab:**

- Amount up: owes more; allocations unchanged.
- Amount down below what's been paid on it: the excess is freed from its
  allocations (latest payment first), then reconcile re-applies freed money
  FIFO to other unpaid purchases; any rest becomes tab credit.
- Moved to another tab, or "Pay later" turned off: treated as removing it from
  the tab (freed money reconciled on the old tab), then linking to the new tab.
- Moving to a budget in a currency other than the tab's: blocked, with the
  reason (both in the form and in the existing Move sheet).

**Delete a purchase:** link and allocations cascade; payment money is
reconciled. Deleting a whole budget (which already deletes its expenses) does
the same for every tab touched.

- Purchase with **no payment money on it**: the existing swipe/delete + Undo
  SnackBar is kept. The delete returns a snapshot of the tab link; Undo
  re-creates the expense **and** its link (then reconciles), so it comes back
  on its tab.
- Purchase **with payment money on it**: the delete asks first with a
  confirmation dialog stating the outcome (see "Never silent"), and offers no
  Undo afterwards. This replaces the instant delete for those rows only.

**What `is_manual` changes:** whenever money must be taken off allocations
(payment amount reduced, purchase reduced, reconcile trimming), automatic
(FIFO) allocations are trimmed before manual ones; within each group the order
stated above applies. It is also shown in payment history ("you chose these").

**Never silent.** Before saving any edit/delete of a purchase that has payment
money on it, the user sees what will happen, e.g. "2.000 already paid on this
meal will go towards your 3 Nov lunch" or "… will stay on the tab as credit".
The budget-delete confirmation adds a line when tab purchases are inside it.

**reconcile(tab):** trim any allocation that exceeds its purchase's owes
(latest payment first) → apply every payment's unapplied money, oldest payment
first, FIFO to purchases still owing → assert the invariant. Pure function over
in-memory rows; the repository writes the diff.

## 6. Expense integration (the "counted once" rules)

- Pay Later never creates or deletes expenses on its own. Only the user's
  Add/Edit Expense save, expense delete, and budget delete touch them.
- Budget remaining, Safe-to-Spend, reports, history, insights, home widget:
  unchanged code paths; a tab purchase is just an expense to them.
- Payments are invisible to every existing feature.
- `expenses.bill_id` is unrelated and untouched. An expense can't be both a bill
  payment and on a tab (bill payments are created by Pay Bill, which never
  shows the Pay later choice).

## 7. Screens and flows

Follows the Monivo M3 design system (tokens, `AppSection`, `AppSurface`,
`AppList`, `AppNotice`/`StatusCard`, `EmptyState`, `AppFab`, motion tokens).
No new packages; charts with the existing fl_chart setup.

**Add/Edit Expense form** (`expense_form_screen.dart`):
- New "Paid" choice below amount: "Now" (default, today's behaviour) / "Pay
  later". Choosing Pay later reveals a tab selector listing non-archived tabs
  in the selected budget's currency; other-currency tabs are listed disabled
  with the reason. "New tab" opens the tab form and returns with it selected.
- The choice is shown to every user, tabs or not (user decision 2026-11-01).
  "Now" is the default and saves exactly as today: same validation, same
  writes, no link row.
- When no tabs exist, choosing "Pay later" offers "Create your first tab"; the
  tab form returns to the expense form with the new tab selected and the
  user's entered amount/date/note intact. Currency compatibility is still
  checked against the selected budget.
- Opened with a tab preselected (from the tab screen), Pay later is already
  chosen and the tab's default category is selected.
- Save writes expense + link in one transaction.
- Quick Add sheet: unchanged.

**Expense details**: when on a tab, a row "On Campus cafeteria · paid 2.000 of
3.500" linking to the tab.

**Pay Later overview** (`/pay-later`, pushed route like `/bills`):
- Total owed per currency (never summed across currencies), overdue amount,
  next settle-up.
- This month: added to tabs, paid.
- Tabs list: name, icon, owed, next settle-up, overdue badge. Archived tabs in a
  collapsed section.
- Recent purchases and recent payments (5 each, "See all").
- Charts: monthly added vs paid (bars, last 6 months); owed over time (line).
  One currency at a time when tabs span currencies.
- FAB: Add to a tab. Actions: New tab, Record payment.
- Empty state: one line on what a tab is + "Create a tab".

**Tab detail** (`/pay-later/:id`):
- Header: owed (or in credit), overdue, next settle-up, total added, total paid.
- Actions: Add to tab, Record payment, Settle all, Edit, Archive.
- Segments: Purchases (grouped by period when the tab has a rhythm; each
  period shows its total, paid, owed and settle-up day; status per purchase) ·
  Payments (each payment with what it covered and the balance after it).
- Category-wise breakdown of this tab's purchases (by expense category).

**Payment sheet**: amount (prefilled with owed for Settle all), date (≤ today),
note, "Choose what this pays" expander with purchase checkboxes. Shows the
balance after the payment before saving.

**Tab form**: name, category, currency (defaults to active budget's; locked
once used), rhythm (On demand / Every 7 / 14 / 21 / 30 days / Custom days /
Monthly on day / Pick a date), anchor (defaults today), reminder toggle and
offset, contact, note, default expense category.

**Entry points**: Home gets a compact "Pay later" row (total owed, next
settle-up) shown **only when at least one non-archived tab exists**; Settings →
"Pay later" always. Home with no tabs renders exactly as today (goldens
unchanged).

**Archive / delete a tab**: archive only when owed and credit are both zero
(otherwise the button explains why). Archived tabs can't take new purchases.
If a later edit (expense edit/move/delete from History, budget delete) leaves
an archived tab with a balance or credit, the tab stays archived but is listed
with the active tabs under an "Archived, has a balance" notice, and its balance
counts in every total. Debt is never hidden: overview totals sum every tab with
a non-zero balance, archived or not.
Delete is offered for a tab with no purchases and no payments; for a used tab
the user archives instead. Expenses are never deleted by tab actions.

## 8. Reminders

- Uses the existing notification plumbing (`NotificationService`, as
  `ScheduleBillReminderUseCase` does), separate id range from bills.
- One pending reminder per tab: on (settle-up day − offset) at the same time of
  day bills use, scheduled only when reminder is on, rhythm isn't on_demand,
  and the tab owes > 0.
- Text has no amount (it would be stale by the time it fires):
  "Campus cafeteria: settle-up day" / "…settle-up in 2 days". Tapping opens the
  tab.
- Rescheduled after every tab write (purchase, payment, edit, archive) and on
  app start / restore, like bills.
- A reminder never records a payment.

## 9. Backup, restore, import, export

- JSON backup and restore include the four tables through `DataCodec`; the
  round-trip test covers every new column.
- Restoring an older backup (no tab data) leaves Pay Later empty.
- The JSON data export (`monivo_export`) and JSON/CSV import are **unchanged**:
  like bills today, tab data is not part of them. Imported expenses arrive as
  ordinary expenses. Only full backup/restore (which replaces everything)
  carries tabs, so no merge conflicts can arise.
- CSV export is unchanged.

## 10. Architecture (fits current conventions)

`lib/features/pay_later/` with `data/` (datasource, models, repository impl),
`domain/` (entities, repository interface, use cases, pure services:
`PayLaterLedger` for balances/status/periods/overdue, `PayLaterAllocator` for
FIFO/manual/reconcile), `presentation/` (blocs, pages, widgets), plus a failure
copy file like bills/expenses. Registered in the existing get_it setup; routes
in `app_router.dart`; refresh through the existing refresh bus so Home and the
tab screens update after expense edits.

Use cases (names follow the repo's `XxxUseCase` style): CreateTab, UpdateTab,
ArchiveTab, DeleteTab, GetTabs, GetTabLedger, LinkExpenseToTab (used by the
expense save), RecordPayment, UpdatePayment, DeletePayment,
ReconcileTab, GetPayLaterOverview, GetPayLaterAnalytics,
ScheduleTabReminder. Expense create/update/delete use cases gain the tab link
and reconciliation inside their existing transaction.

## 11. Testing

- Ledger/allocator unit tests: owed, status, FIFO order ties, manual, overflow,
  multiple payments, edit/delete of payments and purchases, credit invariant,
  rounding at 0/2/3-decimal currencies.
- Periods: every_days before/after anchor, monthly day 31 in February,
  manual_date, overdue, DST (run suite also under `TZ=America/New_York`).
- Repository tests on an in-memory database: transactions roll back on
  failure, cascades, no orphans, budget delete with tab purchases.
- Migration test v8 → v9 on a v8 database with data: existing rows identical,
  new tables empty, schema parity test updated.
- Counted-once tests: budget remaining, Safe-to-Spend and report totals are the
  same with and without a payment; a tab purchase changes them exactly as an
  ordinary expense does.
- Regression: full existing suite and goldens pass. Expected, reviewed
  changes only: the expense form (new "Paid" row) and the Settings golden (new
  "Pay later" row). Every other golden unchanged.
- Widget tests: Pay later choice in the form, tab detail, payment sheet,
  confirmation copy for edit/delete with payments.
- Backup round-trip including the new tables.

## 12. Calls the builder (Claude) made

- Tab categories trimmed to five (Bills owns accommodation/utilities/services).
- Settle-up day = first day of the next period.
- Credit only arises from edits/deletes, never from recording a payment.
- Archive requires a zero balance; used tabs can't be deleted.
- Home row only when a tab exists; Quick Add unchanged.
- One overview screen plus tab detail instead of five sub-tabs
  (Overview/Accounts/Transactions/Payments/Analytics from the original brief);
  the same information is on the two screens.
- Multi-item purchases out of scope (one expense per item).
- Manual settle dates: `rhythm_anchor` reused as the previous settle date.
- Delete with payment money asks first (no Undo); otherwise swipe + Undo
  restores the purchase onto its tab.
- `is_manual`: automatic allocations are trimmed before manual ones.
- JSON export/import leave tab data out (as with bills); backup/restore
  carries it.
- Archived tabs that regain a balance reappear and always count in totals.

## 13. Left to the builder

Widget layout details, chart styling within tokens, exact copy beyond the
examples above, file split inside the feature folder, test file organisation.
