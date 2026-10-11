# Monivo UX remediation: progress

Tracks the fixes for the issues in [`docs/design/ux-audit-2026-10-10.md`](design/ux-audit-2026-10-10.md). The audit report itself is not edited.

- **Branch:** `fix/monivo-ux-p0-critical`, from `main` at `c8fa6e1b`. P0 is committed in `3aa6ce2e`.
- **Release:** the P0 fixes ship in **1.0.0**, listed in `CHANGELOG.md` and `RELEASE_NOTES.md`.
- **Phase:** P0 (UX-001 to UX-012) is implemented. P1 has not started and waits for review.

## Status key

| Status | Meaning |
|---|---|
| **Fixed and verified** | Root cause fixed. Regression tests pass, and where noted the test was shown to fail on the old code. |
| **Fixed; device check needed** | Code and tests done. A platform behaviour (system dialog, biometrics, overnight resume) still needs a run on a phone. |
| **Blocked** | Waiting on a product decision. |

## P0 summary

| ID | Status | Fix in one line |
|---|---|---|
| UX-001 | Fixed; device check needed | A day-change signal reloads Home, the widget, Reports and Expenses on resume and at midnight |
| UX-002 | Fixed; device check needed | Back up saves through the system "save" dialog or the share sheet; success is reported only when the file reached the user |
| UX-003 | Fixed and verified | Exports are marked and named as exports; Restore recognises one and points to Import |
| UX-004 | Fixed and verified | A currency change on a budget with expenses warns inline and needs confirmation; nothing is converted |
| UX-005 | Fixed and verified | The move sheet won't move an expense across currencies; the editor asks before saving one |
| UX-006 | Fixed and verified | Home's "Coming up" lists overdue bills first, says how many, in the critical tone |
| UX-007 | Fixed and verified | The combined Expenses view takes its currency from the rows on screen |
| UX-008 | Fixed and verified | CSV re-import skips expenses already present (by id) and counts every skipped row by reason |
| UX-009 | Fixed and verified | JSON import accepts tags as a list, the stored JSON string or comma text, and rejects malformed ones before writing |
| UX-010 | Fixed; device check needed | The PDF uses the report's currency and embeds Manrope plus the Omani Rial font |
| UX-011 | Fixed and verified | Turning the lock on or off takes effect at once; the setting is re-read on resume |
| UX-012 | Fixed; device check needed | The lock never opens unless the user is confirmed; a PIN-only phone can use it; failures explain how to recover |

The brief's app-lock guidance asked not to re-lock while the app's own file picker or share sheet is open. That is part of audit item **UX-018 (P1)**, and the guard needed for it is in this batch (see UX-002/UX-012 below). The rest of UX-018 (auto-prompt on resume, a grace period for ordinary backgrounding) is still open for P1.

## Product decisions taken as safe defaults

None of these changes stored data on its own; each is reversible.

| ID | Decision | Alternatives not taken |
|---|---|---|
| UX-004 | Allow a currency change on a budget that has expenses only after an explicit confirmation that says amounts are not converted. Correcting a wrong currency is legitimate, for example a budget made in INR by mistake (see UX-016). | Block the change completely, and point to a new budget instead. |
| UX-005 | The move sheet blocks cross-currency moves, because nothing there can correct the amount. The editor allows a change only with confirmation, because the amount can be fixed in the same edit. | Block both. Or convert, which would need an exchange-rate policy; not done. |
| UX-008 | A duplicate means the same expense id (the CSV `id` column). Rows without an id are always added. | Content matching (date + amount + note), rejected: two real, identical coffees are not duplicates. |
| UX-008 | Rows whose currency differs from their budget, or that no budget uses, are skipped and counted. | Import them anyway (the old behaviour, which relabels them). |
| UX-002 | Two destinations: "Save to this device" (system save dialog) and "Share". The backup file is now written to the temporary folder, not the app's documents folder. | Share only. Keeping private copies in documents (they could never be restored). |
| UX-012 | The lock can be turned on with any device screen lock (PIN, pattern, password), not only biometrics: unlocking always accepted the screen lock. With nothing to confirm against, the gate stays up and explains how to set up a screen lock. | Keep requiring biometrics. Fail open (the old behaviour). |
| Lock guard | While the app's own system screen is open, the gate skips locking for up to 5 minutes. Past that, it locks on return. | No cap. A shorter cap. |

## Per-issue detail

### UX-001 (P0): Home and the widget kept yesterday's figures

- **Root cause:** nothing reacted to resume or a date change. `DashboardBloc` reloaded only on data buses, and the only lifecycle observer in `lib/` was the lock gate.
- **Fix:**
  - New `RefreshBuses.day`, fed by `DayChangeWatcher`. It checks the calendar day on every resume (`AppLifecycleListener`) and just after local midnight while the app is in the foreground.
  - The dashboard, the home-screen widget listener, Reports and the Expenses history all reload on it.
  - Started and disposed in `SmartBudgetApp`.
- **Files:**
  - `lib/core/events/day_change_watcher.dart` (new)
  - `lib/core/events/refresh_bus.dart`
  - `lib/main.dart`
  - `lib/features/dashboard/presentation/bloc/dashboard_bloc.dart`
  - `lib/features/widgets/widget_refresh_listener.dart`
  - `lib/features/reports/presentation/bloc/reports_bloc.dart`
  - `lib/features/expenses/presentation/history/bloc/expense_history_bloc.dart`
- **Tests:**
  - `test/core/events/day_change_watcher_test.dart` (4).
  - `test/features/dashboard/presentation/bloc/dashboard_day_change_test.dart` (1, real engine, injected clock). It times out on the old code (checked by removing the subscription); it passes with the fix.
- **Device check:** leave the app in the background over midnight, or change the device date, then resume. Home must show today's figures; the widget must stop saying "Tap to update".

### UX-002 (P0): the backup file was unreachable

- **Root cause:** `BackupService.createBackup` wrote to the app's private documents folder and returned the path. Settings showed "Backup created." and nothing delivered the file.
- **Fix:**
  - Back up now opens a sheet: "Save to this device" or "Share".
  - `FileDeliveryService` uses `FilePicker.saveFile` (Android writes through the system create-document dialog; iOS through the export picker) or `Share.shareXFiles`, and reports the outcome.
  - Settings says "Backup saved…", "Backup shared.", "Backup sent to the share sheet…" or "Backup not saved…". A cancelled save is never reported as a success.
  - The file is named `monivo-backup-YYYY-MM-DD-HHmm.json` and written to the temporary folder.
- **Files:**
  - `lib/features/settings/domain/services/file_delivery_service.dart` (new)
  - `lib/features/settings/presentation/widgets/backup_destination_sheet.dart` (new)
  - `lib/features/settings/domain/services/backup_service.dart`
  - `lib/features/settings/domain/usecases/backup_data_usecase.dart`
  - `lib/features/settings/presentation/bloc/settings_event.dart`
  - `lib/features/settings/presentation/bloc/settings_bloc.dart`
  - `lib/features/settings/presentation/pages/settings_screen.dart`
- **Tests:**
  - `test/features/settings/domain/services/backup_delivery_test.dart`: every outcome passes through; a failed delivery is an error; the file name.
  - `settings_bloc_test.dart`: the message for each outcome.
  - `settings_screen_test.dart`: the sheet appears, and nothing is made until a destination is picked.
- **Device check:**
  - Back up › Save to this device › pick Downloads, then Restore › pick that file.
  - Back up › Share › Drive.
  - Cancel each, and confirm the message says "not saved".
- **Note:** old builds' private `backup_*.json` files stay in app storage; they are not deleted.

### UX-003 (P0): the export looked like a backup and Restore called it damaged

- **Root cause:** the JSON export was named `budget_backup_*.json` and shared as "Monivo Backup", but carried no `type`. Restore required `type: monivo_backup` and reported "damaged".
- **Fix:**
  - Exports carry `type: monivo_export`, are named `monivo_export_*.json` and are shared as "Monivo export".
  - `BackupService.restore` recognises an export (marked, or an older one by its shape) and throws `WrongFileKindException`. That maps to the new `SettingsErrorType.wrongFileKind`, whose message is shown as written: "This is a Monivo export, not a backup… use Import instead. Nothing was changed."
  - The export sheet says "Not a backup: it leaves out bills, so use Back up to keep everything."
- **Files:**
  - `export_service.dart`
  - `backup_service.dart`
  - `restore_data_usecase.dart`
  - `settings_failure.dart`
  - `settings_bloc.dart`
  - `data_format_sheet.dart`
- **Tests:**
  - `backup_delivery_test.dart` (4): the marker; the legacy shape; Restore refuses an export and leaves the data as it was; a real backup still restores.
  - `settings_bloc_test.dart` (wrong-kind message).
  - `settings_screen_test.dart` (sheet copy).

### UX-004 (P0): a currency change silently relabelled expenses

- **Root cause:** expenses have no currency column and inherit their budget's. The edit form changed the currency with no check; the only warning covered linked bills.
- **Fix:**
  - The form reads how many expenses the budget holds, best effort, through `GetExpensesUseCase`.
  - Changing the currency shows an inline warning: "The N expenses in this budget keep their amounts and will be counted in OMR. Nothing is converted."
  - Saving asks "Change currency to OMR?" with an example ("₹500 will read ⃄ 500"). "Keep INR" saves nothing.
  - If the count can't be read, the warning and the question still appear; a budget with no expenses changes without asking.
- **Files:** `lib/features/budget/presentation/pages/budget_form_screen.dart`
- **Tests:** `budget_form_set_aside_test.dart` (3): warn, confirm, cancel; no expenses; count unknown.

### UX-005 (P0): moves kept the number in another currency

- **Root cause:** the move sheet and the form's budget picker ignored currency; a move only rewrote `budgetId`.
- **Fix:**
  - The move sheet lists each budget with its currency. Budgets in another currency are disabled, with "Uses USD. Amounts aren't converted, so this expense can't move here." A defensive check after the pick does the same.
  - In the editor, the picker names currencies when budgets differ. Changing an edited expense to another currency shows a warning and asks "Count this in USD?" before saving. "Go back" saves nothing.
- **Files:**
  - `lib/features/expenses/presentation/widgets/move_expense_sheet.dart`
  - `lib/features/expenses/presentation/pages/expense_form_screen.dart`
- **Tests:**
  - `test/features/expenses/presentation/widgets/move_expense_sheet_test.dart` (2).
  - `expense_form_screen_test.dart` (2).
- **Not done (by design):** no domain-level guard in `UpdateExpenseUseCase`, because the editor path legitimately allows a confirmed change. Add one later if wanted.

### UX-006 (P0): overdue bills vanished from Home

- **Root cause:** `getUpcomingBills` read only bills due today or later.
- **Fix:**
  - New `BillRepository.getOverdueBills(today:)`: unpaid bills due before today, the longest overdue first.
  - The dashboard lists those, then the upcoming ones. Each list is read separately, so one failing never hides the other.
  - "Coming up" adds "1 bill is overdue" and draws "N days overdue" in the critical tone.
- **Files:**
  - `bill_repository.dart`
  - `bill_local_datasource.dart` and `bill_local_datasource_impl.dart`
  - `bill_repository_impl.dart`
  - `dashboard_bloc.dart`
  - `upcoming_bills_section.dart`
  - the four test fakes
- **Tests:**
  - `test/features/dashboard/presentation/bloc/dashboard_overdue_bills_test.dart` (2, real database).
  - `upcoming_bills_section_test.dart` (2).

### UX-007 (P0): ₹ printed above rows in another currency

- **Root cause:** `displayCurrency` looked only at the selected budgets. A mixed selection gave null, and `symbolFor(null)` is ₹.
- **Fix:** when the selection mixes currencies but every visible row shares one, use that one.
- **Files:** `expense_history_state.dart`
- **Tests:** `expense_history_screen_test.dart` (1). It fails on the old logic, which was checked.

### UX-008 (P0): CSV re-import doubled expenses and hid skipped rows

- **Root cause:** every row got a new UUID, and unreadable rows were dropped without being counted. Rows that named no budget went to an arbitrary budget, and the currency column was ignored.
- **Fix:**
  - A row whose `id` exists, or repeats in the file, is skipped as a duplicate. The id is kept on insert, so the next re-import recognises it.
  - Unreadable rows are counted.
  - A row whose currency differs from its budget is skipped. Rows that name no budget go to a budget in their currency, preferring one whose period holds the date.
  - With no budgets at all, one is made in the first currency and other currencies are skipped.
  - Imports return an `ImportReport`. Settings says, for example, "Imported 3 expenses. Skipped 4 rows: 2 already on this device, 1 couldn't be read and 1 in a currency none of your budgets use." A re-import that adds nothing says "Nothing new to import…".
  - JSON imports now report added and updated counts too.
- **Files:**
  - `import_service.dart`
  - `import_report.dart` (new)
  - `import_data_usecase.dart`
  - `settings_bloc.dart`
  - `data_format_sheet.dart`
- **Tests:**
  - `import_service_test.dart`: export imported twice; duplicate ids in one file; currency mismatch; rows routed by currency; no budgets yet; existing tests moved to the report.
  - `settings_bloc_test.dart` (message wording).

### UX-009 (P0): JSON import failed on tagged expenses

- **Root cause:** the export writes the stored tags string; the import cast it to `List` and threw.
- **Fix:**
  - `ImportService.normalizeTags` accepts a JSON list, the stored JSON string, or comma-separated text, and stores the JSON list the app reads. Empty tags are stored as null.
  - Validation rejects any other type before anything is written.
  - CSV tags go through the same path, so comma tags from a spreadsheet now show in the app; before, they were stored as text the app couldn't read.
- **Files:** `import_service.dart`
- **Tests:** `import_service_test.dart` (7). The tagged round-trip fails on the old cast, which was checked. One existing test now asserts the decoded tags instead of the raw string.

### UX-010 (P0): wrong currency and boxes in the PDF

- **Root cause:** the currency came from `currentBudget` (null outside the current month, falling back to ₹). The built-in Helvetica draws Latin-1 only, so ₹, €, the OMR sign, "—" and "•" became boxes.
- **Fix:**
  - The PDF uses `data.currency`, the report's own.
  - `PdfFonts` embeds `Manrope-Regular/Bold` with `MonivoOmaniRial` as a fallback.
  - Amounts show at the currency's real precision (OMR keeps its fils). A symbol the embedded fonts can't draw (the dirham's Arabic letters) is written as its ISO code ("AED 10.50"). Bidi marks are removed.
- **Files:** `lib/features/reports/domain/usecases/export_pdf_usecase.dart`
- **Tests:** `test/features/reports/domain/usecases/export_pdf_usecase_test.dart` (7): glyph coverage; formats; ISO fallback; no currency; OMR/AED/INR documents build with TrueType fonts.
- **Device check:** export a PDF for an INR budget (This Month) and a USD or OMR budget (Last Month), then open it.

### UX-011 (P0): lock changes needed a restart

- **Root cause:** `AppLockBloc` read the setting only at start, and Settings never told it about a change.
- **Fix:**
  - New `AppLockPreferenceChanged`: Settings calls `onLockPreferenceChanged` after a successful save (wired in DI).
  - New `AppLockSyncRequested`: the gate sends it on every resume, so a restore is honoured. An unreadable setting keeps the known value.
- **Files:**
  - `app_lock_bloc.dart` and `app_lock_event.dart`
  - `biometric_gate_screen.dart`
  - `settings_bloc.dart`
  - `injection.dart`
- **Tests:**
  - `app_lock_bloc_test.dart` (4).
  - `settings_bloc_test.dart` (the lock bloc is told after a successful save; never after a failed one).

### UX-012 (P0): the lock failed open

- **Root cause:** with no enrolled biometrics, `isAvailable()` returned false, so the gate never showed. `authenticateNow()` returned `true` on any error or when it couldn't run.
- **Fix:**
  - `BiometricInitializer.isLockEnabled()` is the stored setting alone.
  - `authenticateNow()` returns a `LockAuthResult`: success, failed, unavailable, lockedOut or error. `BiometricService.authenticateForUnlock` maps the `local_auth` error codes.
  - Only `success` unlocks. The gate explains each other result, for example "This phone has no screen lock or fingerprint set up… Set up a screen lock in your phone's settings, then tap Unlock." or "Too many attempts…".
  - Settings allows the lock with any screen lock, and wraps its own prompt in a session so it can't lock the app mid-toggle.
  - The unused, fail-open `authenticateIfNeeded` was removed.
- **Lock guard:** `SystemUiSession` (`lib/core/platform/`) wraps the backup save and share, export shares, Reports CSV and PDF shares, the Import and Restore pickers, and the receipt camera and gallery. The gate skips locking during a session; one longer than 5 minutes locks on return.
- **Files:**
  - `lock_auth_result.dart` (new)
  - `system_ui_session.dart` (new)
  - `biometric_initializer.dart`
  - `biometric_service.dart`
  - `app_lock_bloc.dart`
  - `biometric_gate_screen.dart`
  - `settings_bloc.dart`
  - `export_service.dart`, `export_csv_usecase.dart`, `export_pdf_usecase.dart`
  - `receipt_storage_service.dart`
  - `settings_screen.dart`
- **Tests:**
  - `test/core/biometric/biometric_initializer_test.dart` (6).
  - `app_lock_bloc_test.dart` (3 outcome messages).
  - `biometric_gate_screen_test.dart` (2: a picker doesn't lock; a long one locks on return).
  - `settings_bloc_test.dart` (a PIN-only phone can enable the lock).
- **Device check:**
  - Enable the lock, then remove all fingerprints, then cold start: the gate must stay up and unlock with the PIN.
  - Remove the screen lock too: the gate must explain how to set one up.
  - Fail 5+ times: the lockout message.
  - Export or Restore with the lock on: no re-lock.

## Test changes that touch existing pins

- Two mock files regenerated with a filtered `build_runner` (`app_lock_bloc_test.mocks.dart`, `settings_bloc_test.mocks.dart`). The run also deleted four unrelated mock files through `--delete-conflicting-outputs`; they were restored exactly from `HEAD`.
- `settings_bloc_test.dart`:
  - "enable with no enrolled biometric shows setup message" is replaced. A PIN-only phone now can enable the lock (UX-012).
  - The unsupported-device message changed.
  - JSON import says "Imported 12 expenses." instead of "Import complete.".
- `import_service_test.dart`: results are `ImportReport`; the round-trip asserts decoded tags.
- `polish_golden_test.dart`: the lock fake implements the new initializer API. The `lock_screen` golden is unchanged.
- Golden `test/goldens/goldens/settings.{light,dark}.1x.png` updated after inspection. The only change is the "Back up" row: it now has a chevron like Export and Import (it opens a sheet), and its subtitle wraps one word earlier. The 2× images are unchanged.

## Commands and results

| Command | Result |
|---|---|
| `flutter test` (baseline, before any change) | 1,779 passed |
| Focused suites after each group (dashboard + bills, expenses, settings, budget, reports, biometric) | All passed |
| Failing-on-old-code checks for UX-001, UX-007 and UX-009 (temporarily reverting the fix) | Each test failed without the fix and passed with it |
| `dart run build_runner build --build-filter=…` for the two mock files | Regenerated; four mocks deleted by the tool were restored from `HEAD` |
| `flutter test --update-goldens test/goldens/settings_golden_test.dart --plain-name settings` | Only the inspected settings golden was rewritten |

## Final verification

| Check | Result |
|---|---|
| `flutter test` (full suite, after the last code change) | **1,850 passed, 0 failed** (baseline 1,779, plus 71 new tests) |
| `TZ=America/New_York flutter test` (full suite) | **1,850 passed, 0 failed** |
| `flutter analyze` | No issues |
| `dart format --set-exit-if-changed` on the 62 changed Dart files | 0 to change |
| Goldens | Only `settings.{light,dark}.1x.png` changed, inspected and intended (see above). Every other golden is unchanged. |

**Not run:** no device or emulator session, no iOS, no TalkBack or VoiceOver. The "device check" items above are still owed.

**Known risks:**
- The lock is now stricter: a phone with the lock on and no screen lock is held at the gate until one is set up. Check this on a device before release.
- The system save dialog and the share sheet are platform UI. Their outcome reporting is unit-tested through a fake, not on a phone.
- A JSON data file whose budget id already exists here with a different currency still overwrites that budget's currency on import (merge semantics, unchanged). This is rare; it is noted for a later item.
- Backups and exports still fail on iPad until UX-019 (P1) adds `sharePositionOrigin`.
