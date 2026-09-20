# Offline-first

Smart Monivo has no account, no server and no sync. Every feature works in
aeroplane mode, and the only network call in the app is an optional check for
a newer GitHub release.

## What that buys, and what it costs

- **No sign-in, no latency, no spinner on launch.** The dashboard renders
  from local SQLite.
- **The device is the source of truth.** There is no remote copy to fall back
  on, which makes backup and restore a first-class feature rather than a
  convenience — see [backup_restore.md](backup_restore.md).
- **No conflict resolution, no merge logic, no offline queue.** The whole
  class of problems does not exist.

## Where data lives

| Data | Home |
| --- | --- |
| Budgets, expenses, categories, bills, bill payments | SQLite via Drift (`smart_monivo_db`) |
| App settings (theme, palette, currency, notification prefs, biometric flag) | `settings` key/value table, so backups include them |
| Active budget id, first-launch flag | `SharedPreferences` (`PreferenceKeys`) |
| Receipt images | App documents directory, path stored on the expense |
| Home-screen widget snapshot | Platform widget storage, written by `HomeWidgetService` |

Settings deliberately live in the database rather than preferences so a
restore brings back the user's configuration along with their data.

## Integrity

Because nothing can be re-fetched, the local database is defended:

- Foreign keys are **enforced** (`PRAGMA foreign_keys = ON` in `beforeOpen`),
  so an expense cannot reference a missing budget or category.
- Every write that affects money runs inside a transaction together with the
  budget recomputation, so a failure leaves no half-applied state.
- Migrations repair before they tighten: schema v5 seeds missing categories
  and re-points dangling references *before* enabling foreign keys, so an
  older database upgrades cleanly instead of failing on first write.
- `PRAGMA integrity_check` runs when an existing database is opened, and
  Settings → Data → Database health runs a deeper application-level check
  (orphan rows, impossible date ranges, invalid amounts) on demand.

## The one network call

`lib/features/app_update/` asks the GitHub releases API whether a newer
version exists, with a 10-second timeout. It is optional, it never blocks the
UI, and a failure is silent apart from the Settings row. Tapping Update opens
the release page in a browser; nothing is downloaded or installed by the app.

## Consequences for contributors

- Never add a code path that requires connectivity to read or write user
  data.
- Treat a schema change as a migration plus a test
  (`test/core/database/app_database_migration_test.dart`) — there is no
  server to re-derive state from.
- Anything shown to the user must be derivable from the local database; if a
  figure needs the network, it does not belong in this app.
