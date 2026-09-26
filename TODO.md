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
- [ ] **Biometric lock** — locking on background, unlocking, and a pending
      widget deep link surviving the unlock.
- [ ] **Animated bottom navigation on device** — the Rive icons load in a
      release build, play once on selection, and settle correctly after
      backgrounding the app.
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

- **Rive asset licence.** `assets/rive/nav_icons.riv` is a Rive Community file
  carried over from the reference project. Confirm its licence and attribution,
  or replace it with a bespoke export, before a store release. Procedure:
  [`assets/rive/README.md`](assets/rive/README.md).
- **Android application ID is still `com.example.monivo`.** Changing it breaks
  the widget provider name, the deep-link scheme and existing installs, so it is
  a deliberate release decision rather than a code cleanup.
- **No `LICENSE` file.**
- **`recurring_expenses` and `savings_goals` tables have no feature.** They are
  in the schema and are backed up, but nothing reads or writes them. Removing
  them needs a migration with no user benefit; leave until a feature needs them.
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
- **Currency conversion.** Each budget stores its own currency. Converting with
  hard-coded rates would present stale numbers as fact.
- **A speed-dial floating action button.** One primary action per screen; bills
  are one tap away in Quick actions.
- **A generic `Result<T>` across features.** The five sealed result types share
  a shape but unifying them would touch every BLoC and test for no user-visible
  gain.
