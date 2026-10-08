# Smart Monivo — open work

Everything here is verified against the source. Items are removed when done
rather than ticked off, so this file stays short and honest.

## Needs a device

The CI and test suite run without hardware, so these can only be confirmed by
hand on a phone:

- [ ] **Notifications** — morning and evening reminders fire at the configured
      times, the status-bar icon renders as a monochrome glyph (not a white
      square), and the morning body updates after adding an expense.
- [ ] **Bill reminders** — a reminder set for *n* days before fires on the right
      day, and marking a recurring bill paid moves the next reminder.
- [ ] **Home-screen widget** — Android and iOS both render, follow the active
      budget, refresh after adding an expense, and the "Add Expense" button deep
      links into the form.
- [ ] **Widget safe-to-spend statuses** — the `short:<amount>` ("… short") and
      `careful` ("Spend carefully") statuses render with the right colours, and
      Android shows "Open app to refresh" for an unknown status. The parser
      changes in `HomeScreenWidgetProvider.kt` and `MonivoWidget.swift` have only
      been compiled (`./gradlew :app:compileDebugKotlin`) and type-checked
      (`swiftc -typecheck`); no device or simulator has run them.
- [ ] **Safe-to-spend after linking and paying a bill** — the daily amount drops
      when a bill is linked, holds when it is paid with "Mark paid & record
      expense", and the widget and morning notification match the dashboard.
- [ ] **Biometric lock** — locking on background, unlocking, and a pending
      widget deep link surviving the unlock.
- [ ] **Bottom navigation on device** — icons cross-fade to filled and pulse
      once on selection, and settle correctly after backgrounding the app.
- [ ] **Reduced motion** — with the system setting on, no animation plays and no
      screen gets stuck.
- [ ] **Large text** — at the largest system font size, the dashboard, expense
      form and reports stay readable without clipping.

## iOS builds

`flutter build ios` works, but only with Swift Package Manager turned off:

```bash
flutter config --no-enable-swift-package-manager
flutter build ios --release --no-codesign
```

**Why.** `home_widget` 0.9.2+1 ships a Swift package that points at a
`FlutterFramework` directory it does not contain, so Xcode fails to resolve
dependencies before compiling anything. The fix upstream is `home_widget`
0.9.3+, which requires Flutter 3.38.1 — this project is pinned to 3.32.8 in
CI and locally, so the upgrade is a separate, deliberate piece of work.

The CI iOS workflow is unaffected: it uses the default CocoaPods path.

**Minimum iOS is 15.0.** Three floors force it: the `home_widget` plugin and
the `MonivoWidget` extension both need 14.0, and current Xcode refuses to
build below 15.0. The Podfile pulls every pod up to the same floor, because
several still declare an iOS 9–12 minimum.

## Known gaps

- **Android application ID is still `com.example.monivo`.** Changing it breaks
  the widget provider name, the deep-link scheme and existing installs, so it is
  a deliberate release decision rather than a code cleanup.
- **No `LICENSE` file.**
- **`recurring_expenses` and `savings_goals` tables have no feature.** They are
  in the schema and are backed up, but nothing reads or writes them. Removing
  them needs a migration with no user benefit; leave until a feature needs them.
  The budget form's "Savings goal" is the `budgets.savings_target` column, not
  this table.
- **Savings contributions are not tracked.** There is no savings ledger and
  there are no transfers, so the safe-to-spend engine deducts the whole savings
  goal for the whole period (`SafeToSpendEntity.savingsContributionsTracked` is
  always false). The app never shows progress toward the goal.
- **The budget list's remaining amount can be stale after a restore or
  import.** `BudgetCard` shows the stored `budgets.remaining_amount`. Expense
  writes recompute it. Restore and JSON import write the value from the file,
  and CSV import adds expenses without recomputing it. The dashboard and the
  safe-to-spend figures use SQL period totals and are not affected.
- **Native widgets do not floor the daily amount.** `HomeWidgetService` writes
  it with two decimals, and Android (`%,.0f`) and iOS round it themselves, so
  the widget can show a whole unit more than the dashboard's floored figure.
- **Backup restore fails for tagged expenses.** `tags` is exported as the
  stored JSON string but read back as a `List`, so restoring a backup that
  contains a tagged expense throws a type error, and the transaction rolls
  back.
- **Bills list summary mixes currencies.** The totals row in
  `bills_list_screen.dart` adds bill amounts across currencies and labels the
  sum with the first bill's currency.
- **Kept-aside and savings inputs accept two decimals,** like the existing
  amount field, so OMR's third decimal cannot be typed.
- **No "move bills" prompt** after creating, duplicating or archiving a
  budget. Unlinked bills are surfaced by the dashboard's "Not linked" notice
  and its Link bills sheet instead.
- **Legacy pooled figure.** `GetSpendingTargetsUseCase.combinedDailyTarget`
  and the deprecated `call()` paths still compute a bill-blind figure across
  budgets. No production surface shows them, and they are kept only for
  existing test doubles.
- **Vestigial notification preferences.** `NotificationSettings` still carries
  `overspendingAlertsEnabled`, `noExpenseReminderEnabled` and quiet hours. They
  are persisted but nothing schedules them, and the toggles are not in Settings.
- **Receipt images are not in backups**, only their file paths.

## Deliberately not doing

Decisions recorded so they are not re-litigated. Full reasoning in
[`docs/money_tracker_gap_analysis.md`](docs/money_tracker_gap_analysis.md).

- **Income tracking.** A budget's amount is the money available; an income
  ledger would fork the safe-spending calculation the product rests on. If it is
  wanted, the shape is an income type that optionally tops up a budget's amount,
  with the formula unchanged.
- **Converting budget amounts.** Each budget stores its own currency, and
  expenses and bills are never converted into it. A linked bill in another
  currency is left out of safe-to-spend and disclosed instead. The standalone
  converter in Settings → Tools uses cached reference rates, never hard-coded
  ones.
- **A speed-dial floating action button.** One primary action per screen; bills
  are one tap away in Quick actions.
- **A generic `Result<T>` across features.** The five sealed result types share
  a shape but unifying them would touch every BLoC and test for no user-visible
  gain.
