# Pay Later — handover (2026-11-02)

Branch `feature/pay-later`, uncommitted. Spec: `docs/superpowers/specs/2026-11-01-pay-later-design.md`.
Plan: `docs/superpowers/plans/2026-11-01-pay-later.md`.

## 1. Architecture

A new feature folder, `lib/features/pay_later/`, with the same Clean Architecture layers as the rest of the app.

**Domain:**
- **Pure services.** These are the money core and have no Flutter or database code.
  - `PayLaterLedger`: owed, credit, overdue, the next settle-up day, the periods, and the "owed after" figure on each payment.
  - `PayLaterAllocator`: FIFO or chosen allocation of payments to purchases, plus `reconcile`, the single function that repairs allocations.
  - `SettleSchedule`: the settle-up rhythms (on demand, every N days, monthly on a day, pick a date).
- **Use cases.**
  - `ManageTab`, `GetTabs`, `GetTabLedger` and `GetPayLaterOverview` manage and read tabs.
  - `GetPayLaterAnalytics` feeds the charts.
  - `TabPurchase` handles create, update, delete, restore and the impact preview.
  - `TabPayment` records, edits and deletes payments.
  - `ReconcileTab` reconciles one tab, all tabs, or around a budget delete.

**Data:**
- A Drift datasource and the repository.
- `TabReminderService`, which listens to the `payLater` and `day` refresh buses and reschedules every tab's reminder.

**Presentation:**
- Screens: the overview, tab detail, and the tab form.
- Blocs and cubits behind them.
- The Home row and the Settings row.
- The payment sheet, the impact dialog, and the charts.

**Integration points in existing code:**
- The expense form, details and history screens. "Paid: Now / Pay later" sits on the form; "Now" runs the old code path unchanged.
- `ExpenseBloc` carries the tab id. When a tab is involved it calls the Pay Later use cases, which wrap the expense write and the link in one transaction.
- `ManageBudgetUseCase`:
  - Budget delete reconciles tabs inside the same transaction.
  - A currency change is refused while the budget holds tab purchases.
- Backup and restore cover the 4 new tables. Restore reconciles inside its own transaction.
- `NotificationService` has one shared tap handler for every notification, Bills included.
- `main.dart` reconciles at startup without blocking it and starts the reminder service.
- `RefreshBuses` gains a `payLater` bus.
- `injection.dart` registers everything as required dependencies. Nothing is optional, so Pay Later can't be silently switched off in production.

## 2. Database (schema 8 → 9)

The migration adds 4 tables and changes no existing table. Foreign keys are on, and every link cascades.

| Table | Holds |
|---|---|
| `pay_later_accounts` | The tab: name, currency, rhythm and anchor, reminder on/off and offset, archived flag, contact, note, default category. |
| `pay_later_entries` | The link from an expense to a tab. Primary key is `expense_id`, cascading from `expenses`. |
| `pay_later_payments` | Settlements: amount, date, note. The id is generated on the device, which guards against double submits. |
| `pay_later_allocations` | How much of each payment covers each purchase, with a manual flag. Unique on (payment, expense). |

- The migration step is idempotent (`IF NOT EXISTS`).
- A v8 fixture plus a parity test make sure a fresh install and an upgraded install get the same schema.
- The backup format keeps its version. An older backup restores with Pay Later empty.

## 3. Accounting flow

**Rules:**
- **A purchase on a tab** is an ordinary expense plus a link row. The budget drops on the day you eat. Reports, history, Safe-to-Spend and the widget see an ordinary expense.
- **A payment** is a settlement, never an expense, and never touches a budget.
- **Owed** = purchases − allocated payments. **Credit** = payments not yet allocated. After reconcile, at least one of owed and credit is 0.
- **Allocation is FIFO by default:** oldest purchase first, ties broken by time, then id. The user can choose purchases manually.
- **Edit or delete a paid purchase:** reconcile releases the money and re-applies it FIFO. The impact dialog shows the user what moves first. A delete that frees paid money can't be undone.
- **Unpaid amounts carry forward** forever. A purchase's currency must match its tab's. A bill payment can't go on a tab.

**Transactions:**
- Each write runs in one Drift transaction across the expense, budget and Pay Later tables, and nested calls become savepoints.
- Rollback tests cover expense insert + budget update + link insert.
- Budget delete and reconcile run in one transaction.
- Restore runs in one transaction.

**Reminders:**
- One pending reminder per tab, at 09:00 on (settle-up day − offset). The text has no amount.
- If that moment has already passed, the following settle-up gets the reminder.
- A reminder never records anything.

## 4. Files

**New:**
- **lib:** 52 files under `lib/features/pay_later/` (23 domain, 5 data, 24 presentation).
- **test:**
  - 24 files under `test/features/pay_later/`.
  - Helpers: `pay_later_fixtures`, `pay_later_fakes`, `pay_later_memory_repository`.
  - `test/fixtures/schema_v8.sql`.
  - Route, bus and expense-integration tests.

**Modified, product code:**
- `app_database.dart` (+ `.g.dart`), `injection.dart`, `refresh_bus.dart`, `app_router.dart`, `main.dart`
- Expenses: `expense_bloc/event/state`, `expense_form_screen`, `expense_details_screen`, `expense_history_screen`, `expense_undo`
- Budget: `manage_budget_usecase`, `budget_details_screen`, `budget_form_screen`
- Settings: `backup_service`, `data_codec`, `notification_service`, `settings_bloc`, `settings_screen`
- `dashboard_screen` (Home row)
- `schedule_bill_reminder_usecase` (tap-handler wiring only)

**Modified, tests:** existing tests only gained fake constructor arguments, plus the v8→v9 version bump in the migration test. No existing assertion changed.

**Goldens:** only `settings.{light,dark}.{1x,2x}.png`, which now show the Pay later row under Bills.

**Untouched:** `lib/features/reports`, `lib/features/widgets`, Quick Add, and every `*.mocks.dart`.

## 5. Tests

- **Full suite:** 2399 passed (after the final review) under the default time zone and under `TZ=America/New_York`. `flutter analyze` is clean.
- **Money core:** tested at 0, 2 and 3 decimal places. Reconcile is tested to be idempotent and to keep its invariant.
- **Real Drift database:**
  - Rollbacks in the shared transaction.
  - Crash recovery around budget delete.
  - Double-submitted payments.
  - The migration from a v8 fixture.
  - A backup round trip.
- **Device QA (Pixel 9 Pro emulator, profile build, OMR):**
  - Creating the first tab from the expense form.
  - 3 meals, one backdated, each lowering the budget once.
  - A partial payment that left the budget unchanged.
  - The impact dialog, and delete asking first.
  - Home and Settings rows, light and dark.
  - A reminder that fired; tapping it opened the tab with the app in the background and with it closed.

## 6. Limitations and open items

1. **Decided: no catch-up reminders** (user decision, 2026-11-02). If a period's reminder day is already gone when its first purchase lands, that period gets no reminder; the next period does. A catch-up reminder could fire twice, because the app keeps no record of which reminders already went off. After a reminder fires, the next one is only scheduled once the app runs again, as with bills.
2. **iOS (pre-existing):** `NotificationService.initialize()` returns false because the Darwin settings request no permission. `NotificationBloc` then reports an error at startup, and the startup `scheduleAll` doesn't run on iOS. Taps still route, thanks to the shared handler. Not fixed here because it is Bills/notification behaviour from before this branch.
3. **Not checked on a device:** backup and restore, tablet layout, the monthly and pick-a-date rhythms, archiving and deleting a tab, iOS. Charts with data have no golden test; look at the chart's top on a device.
4. **Rare failure path:** when a duplicate's source link loads but the copy itself fails to load, Save does nothing until Retry succeeds.
5. **Money formatting (app-wide, pre-existing):** whole OMR amounts show as "⃄ 2" next to "⃄ 0.800". The amount hint is "0.00" for 3-decimal currencies.

**Left on purpose (low risk, reviewed):**
- Purchase pre-checks run outside the transaction. The writes themselves are atomic.
- `validateBackup` doesn't check the 4 new keys. A damaged file gives the generic restore error and rolls back safely.
- `expense_form_screen.dart` (~1100 lines) and `tab_detail_screen.dart` (~750 lines) are worth splitting in a separate refactor.
- An open payment sheet can show a stale "Tab settled" line. The use case still enforces the real limit.

## 7. Decisions made during the build (check these)

Each item is a decision the spec or plan didn't settle; the user can reverse any of them.

**Money and behaviour:**
- On a settle-up day, "next settle-up" reads **today** for every rhythm, so the day you pay is visible, but only while purchases from before today still owe. If they're paid, it points at the following settle-up (or asks for a date on a pick-a-date tab). Changed in the final review (section 8).
- The impact dialog shows only when money already paid would move (amount lowered below paid, tab changed or removed, delete). Raising an amount or editing the note or date shows nothing.
- The "owed at month end" chart sums each tab's owed and never nets one tab's credit against another's debt, so it matches the headline "Owed".
- Editing or deleting a payment on an archived tab is still allowed. A tab with a balance reappears.
- Undoing a deleted purchase whose tab has since been deleted brings it back as a plain expense.
- A budget's currency can't change while it holds tab purchases.
- Duplicating a tab purchase keeps it on the tab when the tab is still usable (not archived, same currency).
- Deleting a budget keeps today's refresh behaviour, plus a Pay Later refresh.

**Reminders:**
- The reminder ids start at 90,000,000. The plan said 81M, which could collide with Bills' 80–89.99M range.
- One service listens for every Pay Later change and reschedules. Write paths don't call it themselves.
- Every notification initialize passes the same tap handler, including Bills. That is wiring only; Bills' notifications behave as before.
- When the reminder moment has passed, the following settle-up gets it, with no catch-up.

**UI:**
- "Pay later" is disabled with an explanation for bill-payment expenses.
- The Home row shows nothing while loading or on error.
- The settle-up line is hidden for tabs that owe nothing.
- The reminder switch is disabled for on-demand tabs and for pick-a-date tabs with no date set.
- The chart axis always leaves at least 8% headroom above the largest value.

**Process:**
- Nothing committed. Reviews used working-tree snapshots.
- The backup format version is unchanged.

## 8. Final review (2026-11-02)

**Fixed:**
- **Currency picker closed the tab form.** `CurrencySelector` already closes its own sheet after a pick, and `TabFormScreen._pickCurrency` popped a second time, which closed the New tab / Edit tab form. The form's extra pop is removed. Settings and the converter never added one.
  - Tests: picking keeps the form open and filled (light and dark), cancelling changes nothing, Edit tab saves the new currency. They push the form on top of another page, as the app does; the old tests had the form at the bottom of the stack, where a second pop closes nothing.
  - Confirmed on the emulator: New tab opened from the expense form (dark) and Edit tab (light).
- **"Settle up today" with nothing due.** The ledger and the reminder now share `PayLaterLedger.nextSettleUpDue`: a settle-up day counts only while purchases dated before it still owe. Before, paying the old period the day before and buying on the settle-up day showed "Settle up today" and could fire a 09:00 "settle-up day" reminder, though nothing was due and the tab wasn't overdue the next day.
- **Period card wording.** The tab detail's period card now says "tomorrow" like every other surface.

**Newly reachable, already handled:** with currency now changeable, a tab created from the expense form can be in another currency. It comes back selected, the form explains it doesn't fit the budget's currency, and Save is blocked. Pinned by a new test.

**Verified with no change:**
- Budget currency guard (in `ManageBudgetUseCase.update`, the only path that can change a budget's currency).
- Raising a paid purchase's amount moves no allocated money.
- Settle-up day, month-end clamping and overdue for every rhythm.
- All eight reminder scenarios, with 33 new tests.

**Left as is (low risk):**
- Reminder ids can rarely collide (about 0.05% at 100 tabs), so one tab could cancel another's reminder.
- Scheduling at exactly 09:00:00 is rejected and only logged.
- Around midnight, the overview header and a period card can briefly disagree until the day reload runs.
