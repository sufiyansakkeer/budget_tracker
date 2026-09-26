# Monivo — Smart Budget Tracker

Monivo is an offline-first personal budgeting app for Android and iOS, built with
Flutter. It is designed around a single idea: a budget is a fixed amount of money
for a specific stretch of time, and the most useful number is how much you can
safely spend **today** without running that amount out early.

**Current version:** `1.3.0+8` (source of truth: [`pubspec.yaml`](pubspec.yaml))
**Repository:** <https://github.com/sufiyansakkeer/budget_tracker>

---

## Overview

Most budgeting apps assume a calendar month. Monivo does not. You create as many
budgets as you need, each with its own amount, currency and start/end dates — a
salary cycle, a two-week trip, a wedding fund — and each one tracks its own
expenses and its own daily safe spending independently.

The problem it solves is pacing. Knowing you have money left is not the same as
knowing whether you can spend today. Monivo continuously recomputes, per budget:

```
Today's Safe Spending = (Budget Amount − Total Spent + Spent Today) ÷ Remaining Days
```

Because Spent Today is added back before dividing, the figure is stable for the
whole day: it tells you what you may spend today, and it does not shrink as you
record expenses during that day. It is recalculated from scratch each new day.

Everything runs on the device. There is no account, no sync service and no
analytics backend. The only network request the app makes is an optional check
against the GitHub Releases API to see whether a newer build exists.

### Multiple budgets, explained

This is the core concept, so it is worth stating precisely.

Each budget is **independent** and owns:

| Property | Scope |
| --- | --- |
| Amount | Per budget |
| Currency | Per budget |
| Start date / end date | Per budget |
| Expenses | Per budget (every expense belongs to exactly one budget) |
| Remaining Budget | Per budget |
| Today's Safe Spending | Per budget |
| Budget progress / status | Per budget |

**Amounts are never combined across budgets.** There is no aggregate daily limit
and no merged remaining balance. The Dashboard shows the Active Budget in full and
lists other budgets running today separately, each with its own figures.

The one place where budgets appear together is the **Combined Expense View** in
the Expenses tab. That is a *viewing and aggregation* feature only: it lists the
expense rows from the budgets you select in a single chronological list so you can
compare them. It does not merge the budgets, their amounts, their periods or their
safe-spending calculations.

---

## Features

### Budget Management

- Create any number of budgets, each with a name, amount, currency and an explicit
  start and end date. Periods may overlap.
- One budget is the **Active Budget** at a time. The Dashboard, Reports and the
  home screen widget follow it; switching is done from the Dashboard, the budget
  list or Settings.
- Per budget: Remaining Budget, overall progress, days passed, remaining days,
  average daily spending, projected period-end spending, projected savings and
  projected overspending.
- Budget status is classified as under budget, near limit or over budget from a
  configurable utilization threshold.
- Budgets can be edited and archived. Archived budgets keep their expenses.
- **Change active budget amount** (Settings) rewrites only the amount; dates and
  expenses stay as they are, and the remaining amount is recomputed from what has
  already been spent.
- **Start new budget period** (Settings) archives the Active Budget and creates
  exactly one fresh 31-day budget starting today, carrying over the amount and
  currency. The operation runs in a single database transaction.

### Expense Management

- Add, edit and delete expenses. Each expense records amount, category, optional
  note, date, time, optional tags and an optional receipt image.
- **Swipe left to delete, with Undo.** Deleting is immediate and a snackbar offers
  Undo for a few seconds; undo restores the same row, so budgets, reports and the
  widget stay consistent either way. No confirmation dialog stands in the way.
- **Press and hold a row** for contextual actions: Edit, Duplicate, Move to another
  budget, Delete. Duplicate opens the form pre-filled from that expense, dated now.
- Moving an expense between budgets credits the budget it left and debits the one
  it joins, inside a single transaction.
- 13 built-in categories (Food, Grocery, Fuel, Shopping, Rent, EMI, Bills, Travel,
  Entertainment, Health, Education, Salary Adjustment, Others), each with its own
  icon and colour.
- **Your own categories.** Settings → Expenses → Categories adds, renames and
  restyles categories (43 icons, 16 colours), archives ones you no longer use and
  deletes custom ones that no expense references. Built-in categories can be
  renamed and restyled but not deleted. Archived categories disappear from pickers
  while history keeps its labels.
- Receipt images are captured with the camera or picked from the photo library and
  stored locally.
- **Expense history** groups entries by the device's local calendar date, with a
  running summary, incremental paging and text search.
- Six sort options: newest first, oldest first, highest amount, lowest amount,
  category, alphabetical. Category sort keeps ordering stable within each day group.
- Filters: category, date range, minimum/maximum amount, tags, and receipt-only.
  Filters combine, and active filters are shown as removable chips.
- Date presets — Today, Yesterday, This week, Last week, This month, Last month,
  This year — as quick chips and in the filter sheet. A custom range reads as a
  single chip ("12 Mar – 15 Mar").
- **Combined Expense View**: select multiple budgets and see their expenses in one
  list. Each row carries a budget-name chip, and an info sheet shows that budget's
  details. See [Multiple budgets, explained](#multiple-budgets-explained).
- All amounts are formatted through a single currency formatter using the budget's
  currency code and symbol.

### Dashboard

- **Today's Safe Spending** hero card for the Active Budget, with Spent Today,
  either "Left today" or "Over by", and a quiet weekly line showing what has been
  spent against this week's share of the budget.
- Budget overview card — how much of the budget is left (or how far over it you
  are), the percentage used, and your position in the budget period (day N of M,
  with the date range).
- **Other budgets today** — a separate section listing every other budget whose
  period includes today, each with its own safe amount. Nothing is summed.
- **Smart Insights** — up to three prioritised observations (see below).
- **Recent expenses** for the Active Budget, with a shortcut to the full history.
- **Upcoming bills** — the next three unpaid bills due today or later, soonest
  first.
- **Quick actions** — Add bill, Bills, Budgets, Reports.
- When no budget covers today, the Dashboard shows a create-budget state instead.

### Reports

Reports are scoped to the **Active Budget's** expenses.

- Period selector: This Week, Last Week, This Month, Last Month, This Year, Custom
  range. The same filter set as the expense history can be applied on top.
- Total spending summary with a spending trend.
- Budget progress card — shown only when the selected range covers the current
  calendar month.
- Category breakdown: pie chart plus ranked per-category analytics.
- **Categories vs previous period** — which categories moved most against the
  equal-length window immediately before the selected range, with the change in
  money and percent, and a "New" marker for categories with no earlier spending.
- Daily spending line chart.
- Bar chart of weekly buckets (month views) or monthly buckets (year views), shown
  when the range produces more than one bucket.
- Week-over-week comparison, shown when a preceding period exists.
- Time analytics: most/least expensive day, most/least active day, highest-spending
  weekday, weekday vs. weekend split.
- Report insights, generated from the figures on screen, collapsible to a short list.
- Export the report as **CSV** or **PDF** through the system share sheet.

Charts are drawn with `fl_chart`.

### Bills & Reminders

- Create bills with a title, optional note, amount, currency, category, due date and
  optional due time.
- 14 bill categories (Rent, Utilities, Electricity, Water, Internet, Phone, EMI,
  Insurance, Subscription, Education, Healthcare, Government, Credit Card, Other).
- Recurrence: one-time, weekly, monthly or yearly, with a configurable interval.
- Status is derived from the due date and payment state — Upcoming, Due Today,
  Overdue or Paid. It is computed, never stored.
- Mark a bill paid or unpaid. Marking a recurring bill paid advances it to its next
  occurrence instead of closing it permanently, and writes a payment-history record.
  The payment record and the bill update are written atomically.
- List filters: All, Upcoming, Due Today, Overdue, Paid, Recurring.
- Per-bill reminders with a configurable lead time in days, delivered as local
  notifications on a dedicated channel. Reminders are never scheduled for a time in
  the past, and reminder IDs are derived from the bill ID so they can be reliably
  cancelled and rescheduled.

### Smart Insights

Smart Insights are **rule-based and deterministic** — there is no AI and no network
call. They are produced by a pure domain service from the Active Budget's summary
and the per-budget daily limits, and at most three are shown, ordered by severity:

1. Per-budget over-limit and near-limit warnings for today.
2. Critical overspending on the Active Budget.
3. Projected period-end overspending at the current daily average.
4. Per-budget weekly-share overspending.
5. Per-budget progress (percentage used, days remaining).
6. Overspending against Today's Safe Spending.
7. Daily and weekly spending-target status.
8. Spending pace relative to the safe allowance.
9. Overall budget progress.
10. Positive outcomes — projected leftover, or simply being within budget.

Every message quotes real figures from local data. When no budget amount is set, a
single informational message is shown instead. Reports carries its own separate
insight generator for the period being viewed.

### Notifications

Two local notification channels, both scheduled in the device's local timezone:

| Channel | Notifications |
| --- | --- |
| `budget_reminders` | Morning "Today's Safe Spending" (one line per budget running today) and an evening summary |
| `bill_reminders` | Per-bill reminders based on each bill's lead time |

- Permission is requested once at app startup. A denial never blocks launch — the
  rest of the app stays fully usable.
- Morning and evening notifications can each be toggled and re-timed in Settings,
  under a master "Daily notifications" switch.
- Schedules survive device restarts via a boot receiver.
- In **debug builds only**, an extra test notification is scheduled one minute after
  launch to verify permission, channel and delivery.

### Security

- Optional biometric app lock (fingerprint / Face ID / device credential), toggled
  in Settings and backed by `local_auth`.
- When enabled, a full-screen gate covers the app until authentication succeeds.
  The system back button is intercepted while locked, and a persistent
  "Re-authenticate" action is always available.
- The app re-locks when it is backgrounded. Dismissing the native biometric prompt
  does not cause an immediate re-lock.
- Lock state is owned by a BLoC, not by the gate widget, and the gate is themed with
  the user's palette and brightness.
- A widget deep link tapped while the app is locked is stashed and replayed only
  after a successful unlock.

### Home Screen Widget

Available on **Android** (App Widgets) and **iOS** (WidgetKit).

The widget shows the **Active Budget only** — never a total across budgets:

- Today's Safe Spending
- Spent Today
- Status (on track, or how much over)
- Remaining Budget and remaining days

Interactions: tapping the widget body opens the Dashboard; tapping "+ Add Expense"
opens the Add Expense screen directly, on both cold and warm start.

Data is computed by the same use cases the Dashboard uses — no duplicated formulas —
and written to shared storage (`SharedPreferences` on Android, an App Group's
`UserDefaults` on iOS). It refreshes when an expense or budget changes, on app
startup, and on the platform's own hourly refresh cycle. When no budget covers
today, the widget shows an empty state.

Sizes: Android declares a 4×2 target cell and is resizable horizontally and
vertically; iOS supports the `systemSmall` and `systemMedium` families.

See [`docs/home_screen_widget_setup.md`](docs/home_screen_widget_setup.md) for the
full data contract and platform setup.

### Theme

- Light, Dark and System modes.
- Eight colour palettes: Default, Blossom Vapor, Mahogany Blaze, Ocean, Forest,
  Sunset, Violet, Rose.
- Material 3 (`useMaterial3: true`) with one shape and typography language across
  cards, sheets, buttons, inputs and chips. The dark theme uses its own surface
  hierarchy rather than a straight inversion of light.
- Switching mode or palette interpolates every colour in place — no restart and no
  flash — and the system status-bar style follows the active brightness.
- Theme mode and palette are persisted and restored on launch.

### Motion

A single set of motion tokens drives the whole app: micro press feedback (~120 ms),
component transitions (~250 ms), screen transitions (~300–350 ms) and emphasized
reveals (~450 ms) for number count-ups, progress sweeps and chart reveals. Route
transitions use shared-axis and fade-through patterns; bottom-navigation branches
cross-fade. Every animation goes through a reduced-motion helper, so the app
degrades gracefully when the platform requests reduced motion.

**Animated bottom navigation.** The four tabs use Rive-animated icons on a Material 3
bar. Selecting a tab plays a short one-shot icon animation while the bar itself draws
the steady selected state — indicator, tint, label weight — from the current index, so
it is always correct after navigating, after returning from a pushed screen and after a
cold start. Nothing loops. If the asset cannot load the icon falls back to its Material
glyph, and under reduced motion the animation is skipped entirely. Details and the
procedure for swapping in your own `.riv` file:
[docs/architecture/rive_navigation.md](docs/architecture/rive_navigation.md).

### Currency

Ten selectable currencies — INR, USD, EUR, AED, OMR, GBP, CAD, AUD, JPY, SGD. A
currency is chosen during onboarding, can be changed in Settings for new budgets and
app-wide display, and each budget also stores its own currency code. All formatting
goes through one central formatter.

### App Updates

Monivo checks the GitHub Releases API
(`https://api.github.com/repos/sufiyansakkeer/budget_tracker/releases/latest`) for a
newer release. The check runs after the first frame renders, so a slow network never
blocks launch, and the request times out after 10 seconds.

Versions are compared semantically after stripping a leading `v` and any `+build`
suffix. When a newer release is found, a dialog is shown once per launch; the check
can also be run manually from Settings, and the release page opens in the browser.

### Data Management

- Export all data as **CSV** or **JSON** via the system share sheet.
- Import from a CSV or JSON file.
- Create a full local **backup** (a versioned JSON file covering every table) and
  restore from one.
- Backups are validated against the expected schema before being applied, and
  imports are validated before committing. Restore replaces everything inside one
  transaction, so a failure leaves the existing data untouched.
- A CSV export re-imports losslessly: the importer matches columns by header name
  rather than position, so a spreadsheet you rearranged still works, and unknown
  categories fall back to "Others" instead of failing.
- **Database health** — an on-demand integrity check (orphaned rows, impossible
  date ranges, invalid amounts) with the result in a sheet.

See [docs/architecture/backup_restore.md](docs/architecture/backup_restore.md).

### Onboarding

A seven-step first-launch flow: welcome, budget name, budget amount, currency,
start date, end date, and a confirmation summary. Completion is persisted, and the router
redirects to onboarding until it is done.

---

## Tech Stack

Every entry below was verified against [`pubspec.yaml`](pubspec.yaml) and the source.

| Area | Package / technology |
| --- | --- |
| Framework | Flutter (Dart SDK `^3.8.1`) |
| State management | `flutter_bloc`, `equatable` |
| Navigation | `go_router` (`StatefulShellRoute` for the bottom-nav tabs) |
| Dependency injection | `get_it` |
| Reactive UI helper | `provider` (currency `ChangeNotifier`) |
| Database | `drift`, `drift_flutter`, `sqlite3_flutter_libs` |
| Key-value storage | `shared_preferences` |
| File system paths | `path_provider`, `path` |
| Charts | `fl_chart` |
| Animated navigation icons | `rive` (0.13 line, pure-Dart runtime) |
| Formatting / i18n | `intl` |
| Notifications | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Biometrics | `local_auth` (+ `local_auth_android`, `local_auth_darwin`, `local_auth_windows`) |
| Receipts | `image_picker` |
| Import / export | `file_picker`, `csv`, `pdf`, `share_plus` |
| Home screen widget | `home_widget` |
| Networking | `http` |
| App metadata | `package_info_plus` |
| External links | `url_launcher` |
| IDs | `uuid` |

**Dev dependencies:** `flutter_test`, `flutter_lints`, `build_runner`, `drift_dev`,
`bloc_test`, `mockito`, `sqlite3` (migration tests), `flutter_launcher_icons`.

Linting uses `package:flutter_lints/flutter.yaml` with no project-specific overrides.

> **Note on code generation.** The only generated file in the project is
> `lib/core/database/app_database.g.dart` (Drift). Entities are hand-written and use
> `Equatable` for value equality.

---

## Architecture

Monivo follows Clean Architecture with a feature-first layout. Each feature owns its
own presentation, domain and data layers.

```
Presentation  (Screens, Widgets)
      ↓  events
BLoC          (flutter_bloc — the only place UI state is produced)
      ↓  calls
Use Cases     (one responsibility each, pure Dart)
      ↓  depends on abstractions
Repositories  (interface in domain/, implementation in data/)
      ↓
Data Sources  (local, Drift-backed; one remote source for GitHub releases)
      ↓
Drift / SQLite  +  SharedPreferences
```

Principles actually applied in the codebase:

- **Separation of concerns.** All budget arithmetic lives in
  `BudgetCalculationService`, a pure class with no Flutter, UI or database imports.
  Smart Insights and report insights are likewise pure domain services. The UI only
  renders what these produce.
- **BLoC state management.** Screens dispatch events; BLoCs invoke use cases and emit
  immutable states. Cross-feature refresh is coordinated through one lightweight
  broadcast channel — `RefreshBuses.expenses`, `.budgets` and `.bills` in
  [`lib/core/events/refresh_bus.dart`](lib/core/events/refresh_bus.dart) — which also
  keeps the home screen widget and the scheduled notifications in sync. A bus carries
  no payload: every listener re-reads from its repository, so nobody acts on a stale
  copy.
- **Repository pattern.** Domain layers depend on repository interfaces only;
  implementations translate between Drift rows/models and domain entities.
- **Domain use cases.** Each meaningful operation is its own use case class, which is
  what makes the business rules directly unit-testable.
- **Typed failures.** Operations return sealed result types — `BudgetResult`,
  `ExpenseResult`, `BillResult`, `SettingsResult`, `ReportResult` — each with
  success and failure variants, rather than letting exceptions cross layers.
- **Offline-first.** Every read and write goes to the local database or local
  preferences. No feature depends on connectivity; the GitHub update check is the
  single network call and fails silently.
- **Memoization.** `BudgetCalculationService` caches its last summary and analytics
  keyed by the input, so repeated Dashboard rebuilds do not recompute.
- **Atomic writes.** Expense creation/update/deletion, budget amount changes, the
  new-period reset and bill payments all run inside database transactions.

### Dependency injection

`lib/core/di/injection.dart` registers around 90 dependencies with `get_it` —
database, data sources, repositories, use cases, services, and BLoCs — using
lazy singletons for shared state and factories for per-screen BLoCs.

### Database

Drift over SQLite, database name `smart_monivo_db`, **schema version 5**.

Foreign keys are **enforced** (`PRAGMA foreign_keys = ON` on every connection), and
the default categories are seeded by the database itself, so an expense can always
be written and can never point at a budget or category that does not exist.

| # | Table | Purpose |
| --- | --- | --- |
| 1 | `budgets` | Budget definitions (amount, currency, start/end dates, archive flag) |
| 2 | `categories` | Expense categories, built-in and user-created, with an archive flag |
| 3 | `expenses` | Expenses, indexed on date, category, budget and `(budget, date)` |
| 4 | `settings` | Key/value application settings |
| 5 | `recurring_expenses` | Defined in the schema; not used by any feature |
| 6 | `savings_goals` | Defined in the schema; not used by any feature |
| 7 | `bills` | Bills, indexed on due date |
| 8 | `bill_payments` | Payment history for recurring bills |

Migrations:

- **v1 → v2** — adds `expenses.time`.
- **v2 → v3** — the single-budget (month/year) to multi-budget (date range) move:
  adds `name`, `startDate`, `endDate`, `isArchived`, `color`, `icon`, `notes` to
  `budgets` and `budgetId` to `expenses`, then backfills existing budgets to
  first-of-month → last-of-month ranges and assigns existing expenses to the first
  budget.
- **v3 → v4** — creates the `bills` and `bill_payments` tables. No backfill.
- **v4 → v5** — hardens the schema so foreign keys can be switched on safely:
  repairs databases whose v3 migration wrote camelCase columns, creates every index
  (older upgrades missed some) plus the composite `(budget_id, date)` index that
  every budget statistic uses, adds `categories.isArchived`, seeds any missing
  default categories, and re-points expenses whose budget or category reference had
  gone dangling. Covered by
  [`test/core/database/app_database_migration_test.dart`](test/core/database/app_database_migration_test.dart),
  which runs a real v4 database through the upgrade.

Aggregates (a budget's total and today's spend, bill totals) are computed with SQL
`SUM`/`COUNT` over the indexed columns rather than by loading rows into Dart.

On opening an existing database, `PRAGMA integrity_check` is run and the result is
logged. Settings → Data → Database health runs a deeper application-level check on
demand.

---

## Project Structure

```
lib/
├── main.dart                      App bootstrap, home-widget wiring, root widget
├── core/
│   ├── biometric/                 App lock BLoC + full-screen gate
│   ├── constants/                 Motion tokens, spacing, GitHub config
│   ├── currency/                  Central formatter + currency ChangeNotifier
│   ├── data/models/               Shared budget model
│   ├── database/                  Drift schema, migrations, generated code
│   ├── di/                        get_it registrations
│   ├── domain/                    Shared entities + database integrity service
│   ├── events/                    Refresh buses (expenses, budgets, bills)
│   ├── navigation/                Animated bottom navigation (Rive icons)
│   ├── notifications/             Startup + rescheduling notification BLoC
│   ├── router/                    GoRouter config, shell, page transitions
│   ├── theme/                     Material 3 themes, palettes, colour tokens
│   └── widgets/                   Shared UI primitives (cards, dialogs, states)
└── features/
    ├── app_update/                GitHub release check
    ├── bills/                     Bills & Reminders
    ├── budget/                    Budgets and the calculation engine
    ├── categories/                Category management (create, archive, delete)
    ├── dashboard/                 Dashboard + Smart Insights
    ├── expenses/                  Expenses and expense history (incl. combined view)
    ├── onboarding/                First-launch flow
    ├── reports/                   Reports, analytics and exports
    ├── settings/                  Settings, theme, backup/export/import, services
    └── widgets/                   Home-screen widget service + refresh listener

android/app/src/main/kotlin/com/example/monivo/
    HomeScreenWidgetProvider.kt    Android App Widget provider
ios/MonivoWidget/
    MonivoWidget.swift             iOS WidgetKit extension
test/                              Mirrors lib/ (69 test files)
docs/
    home_screen_widget_setup.md    Widget architecture and platform setup
    CI_CD.md                       Pipeline, secrets and release process
```

Each feature directory follows the same shape:

```
features/<feature>/
├── data/          datasource/, models/, repository/
├── domain/        entities/, repository/, usecases/, validators/, services/
└── presentation/  bloc/, pages/, widgets/
```

---

## Getting Started

### Prerequisites

- Flutter SDK — CI pins **3.32.8**; use that version or a compatible newer stable.
- Dart SDK `^3.8.1` (bundled with Flutter).
- Android: Android Studio with a JDK 11-compatible toolchain and NDK `29.0.14206865`
  (r29). NDK r28 or newer is required so native libraries are linked for 16 KB
  memory pages; see [16 KB page-size compatibility](#16-kb-page-size-compatibility).
- iOS: Xcode with CocoaPods, on macOS.

### Installation

```bash
git clone https://github.com/sufiyansakkeer/budget_tracker.git
cd budget_tracker
flutter pub get
```

### Code generation

Only required after changing the Drift schema in `lib/core/database/app_database.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated files are committed; CI verifies they are up to date.

### Run

```bash
flutter run
```

### Verify

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test --coverage      # writes coverage/lcov.info
```

### Build

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release --no-codesign   # macOS only
```

Android release signing reads `android/key.properties` (`keyAlias`, `keyPassword`,
`storeFile`, `storePassword`). When that file is absent, release builds fall back to
the debug signing config, which is fine for local testing but not for distribution.

---

## Android Setup

| Item | Value |
| --- | --- |
| Application ID | `com.example.monivo` |
| Namespace | `com.example.monivo` |
| `minSdk` | 23 — required by `home_widget`'s `androidx.work` dependency |
| `compileSdk` / `targetSdk` | Flutter defaults |
| Java / Kotlin target | 11, with core library desugaring enabled |
| NDK | `29.0.14206865` (r29) — see [16 KB page-size compatibility](#16-kb-page-size-compatibility) |

**Permissions declared** in `android/app/src/main/AndroidManifest.xml`:

| Permission | Used for |
| --- | --- |
| `INTERNET` | GitHub release check |
| `CAMERA` | Receipt capture |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | Biometric app lock |
| `POST_NOTIFICATIONS`, `VIBRATE` | Local notifications (runtime prompt on Android 13+) |
| `RECEIVE_BOOT_COMPLETED` | Restoring scheduled notifications after a restart |

The manifest also registers the `HomeScreenWidgetProvider` receiver, the
`flutter_local_notifications` scheduled and boot receivers, and a `monivo://`
deep-link intent filter on `MainActivity`.

### 16 KB page-size compatibility

Android 15+ devices can run with 16 KB memory pages, and Google Play requires
apps that ship native code to be 16 KB compatible. The release APK and AAB are
genuinely aligned — no `android:pageSizeCompat` or other compatibility mode is
used.

The app has no native code of its own. The native libraries in the build come
from Flutter (`libflutter.so`, `libapp.so`), `sqlite3_flutter_libs`
(`libsqlite3.so`), `shared_preferences_android` via AndroidX DataStore
(`libdatastore_shared_counter.so`) and `rive_common` (`librive_text.so`). All
of them are prebuilt with 16 KB alignment except `librive_text.so`, which
`rive_common` compiles from source with CMake and, by default, with NDK 25 —
that produced 4 KB-aligned ELF `LOAD` segments. Two `gradle.properties`
settings fix this at the source rather than patching binaries:

| Setting | Why |
| --- | --- |
| `rive.ndk.version=29.0.14206865` | `rive_common`'s documented hook for choosing its NDK. NDK r28+ links with 16 KB-aligned `LOAD` segments by default. Kept equal to `ndkVersion` in `android/app/build.gradle.kts`. |
| `android.ndk.suppressMinSdkVersionError=21` | NDK r28+ dropped API < 21, and the `rive_common` library module still declares `minSdkVersion 19` for its own native build. This AGP setting builds that code against API 21 instead of failing configuration (error CXX1110). The app's `minSdk` is 23, so nothing below 21 can install it. |

AGP 8.7.3 already stores native libraries uncompressed and 16 KB zip-aligned,
and writes `PAGE_ALIGNMENT_16K` into the bundle configuration.

To verify a build (paths assume the default SDK location on macOS):

```bash
# ELF LOAD segment alignment of every native library in the APK
unzip -o -d /tmp/apk build/app/outputs/flutter-apk/app-release.apk 'lib/*'
for f in /tmp/apk/lib/*/*.so; do
  printf '%-50s ' "${f#/tmp/apk/}"
  ~/Library/Android/sdk/ndk/29.0.14206865/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf -l "$f"     | awk '/LOAD/{print $NF}' | sort -u | tr '
' ' '; echo
done            # every 64-bit library must show 0x4000 or 0x10000

# Zip alignment of the APK for 16 KB pages
~/Library/Android/sdk/build-tools/35.0.0/zipalign -c -P 16 -v 4 build/app/outputs/flutter-apk/app-release.apk

# Bundle configuration (needs bundletool)
java -jar bundletool.jar dump config --bundle=build/app/outputs/bundle/release/app-release.aab
#   "uncompressNativeLibraries": { "enabled": true, "alignment": "PAGE_ALIGNMENT_16K" }

# A 16 KB emulator (Android Studio: an "ps16k" system image) reports
adb shell getconf PAGE_SIZE   # 16384
```

The 32-bit `armeabi-v7a` and `x86` copies of `librive_text.so` and
`libsqlite3.so` remain 4 KB aligned. The 16 KB page-size requirement applies to
64-bit ABIs only: 16 KB devices are 64-bit and load the `arm64-v8a` libraries.

No additional Android Studio configuration is needed for the home screen widget —
the provider, layout and `appwidget-provider` XML are all in the repository. To add
it: long-press the home screen → Widgets → Monivo → drag to place.

---

## iOS Setup

> **Minimum iOS version is 15.0.** The `home_widget` plugin and the
> `MonivoWidget` extension both require iOS 14, and current Xcode refuses to
> build below 15.0, so the Podfile sets 15.0 and pulls every pod up to it.
>
> **Building for iOS needs Swift Package Manager disabled**
> (`flutter config --no-enable-swift-package-manager`) until `home_widget` can
> be upgraded past 0.9.2+1, whose Swift package references a directory it does
> not ship. See [`TODO.md`](TODO.md#ios-builds).

| Item | Value |
| --- | --- |
| Display name | Monivo |
| Widget extension | `ios/MonivoWidget/` (WidgetKit, SwiftUI) |
| Supported widget families | `systemSmall`, `systemMedium` |
| App Group | `group.com.sufiyan.monivo` |
| Deep link scheme | `monivo://` |

**Usage descriptions** in `ios/Runner/Info.plist`:

| Key | Reason |
| --- | --- |
| `NSCameraUsageDescription` | Capturing expense receipts |
| `NSPhotoLibraryUsageDescription` | Attaching receipts from the library |
| `NSFaceIDUsageDescription` | Unlocking the app with Face ID |

**App Group.** Both `ios/Runner/Runner.entitlements` and
`ios/MonivoWidget/MonivoWidget.entitlements` declare
`group.com.sufiyan.monivo`, and `main.dart` calls
`HomeWidget.setAppGroupId('group.com.sufiyan.monivo')` at startup — this must happen
before any widget data is written, or iOS sharing fails silently. Xcode
auto-provisions the App Group for development; for distribution it must be registered
in the Apple Developer portal.

`ios/Podfile` declares a separate `MonivoWidget` target alongside `Runner`.
[`docs/home_screen_widget_setup.md`](docs/home_screen_widget_setup.md) recommends
testing the widget on a physical device rather than the Simulator.

Notification permission is requested at runtime by `flutter_local_notifications`;
no additional capability needs to be enabled for the local-notification flow used
here.

---

## Testing

Tests live under [`test/`](test/), mirroring the `lib/` structure. Every test runs
on the host with `flutter test` — no device or emulator is needed, including the
integration flows. Coverage is concentrated where correctness matters most:

- **Domain services** — budget calculations, analytics (including the category
  comparison), Smart Insights, report insight generation.
- **Use cases** — budget, expense, category, bill, settings, onboarding and
  app-update use cases, plus validators.
- **BLoCs** — dashboard, budget, expense, expense history (including combined
  mode), categories, bills, reports, settings, theme, app lock, notifications.
- **Repositories and data integrity** — expense transaction safety (including that
  moving an expense recomputes both budgets), budget amount changes, the
  **v4 → v5 schema migration** against a captured schema fixture, integrity checks,
  backup/restore validation, CSV round trip.
- **Widgets** — the animated bottom navigation, expense and history widgets,
  category management and its form sheet, the safe-spending hero, the category
  comparison card, settings tiles, theme and currency selectors, update dialog,
  budget form.
- **Integration flows** ([`test/integration/`](test/integration/)) — the real
  datasources, repositories, use cases and BLoCs wired against an in-memory
  database by `app_harness.dart`, covering: create / edit / delete / undo an
  expense, move it between budgets, search; create and switch budgets, safe
  spending across days, delete a budget, start a new period, change the amount;
  build a report, filter it, and watch it refresh after a delete.

`test/helpers/in_memory_database.dart` provides an in-memory Drift database. Mocks
are generated with `mockito`; BLoC assertions use `bloc_test`. The Rive runtime
cannot load inside `flutter test`, so navigation icons fall back to Material glyphs
there automatically — see
[docs/architecture/rive_navigation.md](docs/architecture/rive_navigation.md).

```bash
flutter test                      # everything, including integration flows
flutter test test/integration     # just the end-to-end flows
flutter test --coverage           # with coverage
```

---

## CI/CD

Four GitHub Actions workflows, all pinning Flutter **3.32.8**:

| Workflow | Trigger | Does |
| --- | --- | --- |
| `ci.yml` | Pull requests, pushes to `developer` | pub get, regenerate sources, verify generated files are committed, format check, analyze, test, upload coverage |
| `android-release.yml` | Pushes to `developer`, manual dispatch | Android development APK and AAB |
| `ios-release.yml` | Pushes to `developer`, manual dispatch | Unsigned iOS development build (`--no-codesign`) |
| `release.yml` | Pushes to `main` | Calculates the next patch version and build number, validates, builds a signed APK/AAB, commits the new `pubspec.yaml` version, tags it, and creates or updates the GitHub Release |

The version commit created by `release.yml` contains `[skip ci]`, so a release cannot
trigger another release. Full details, including the required repository secrets, are
in [`docs/CI_CD.md`](docs/CI_CD.md).

---

## Known Limitations

These are current, verified gaps. They are listed so the documentation matches the
code rather than the intent.

- **`recurring_expenses` and `savings_goals` tables have no feature.** They exist in
  the Drift schema and are covered by backup and export, but no screen, BLoC or use
  case reads or writes them.
- **Unused notification preference fields.** `NotificationSettings` still carries
  `overspendingAlertsEnabled`, `noExpenseReminderEnabled` and the quiet-hours fields.
  No scheduling logic implements them and the toggles were removed from Settings.
- **Receipt images are not included in backups or exports.** Only the stored file
  path is, so a restore on another device shows "Receipt file is missing".
- **No currency conversion.** Each budget stores its own currency and amounts are
  formatted in it; amounts are never converted between currencies.
- **No income tracking.** A budget's amount is the money available; there is no
  income ledger. Topping up means editing the budget amount.
- **The Rive navigation asset is a Rive Community file** carried over from the
  reference project. Confirm its licence or swap in a bespoke export before a store
  release — see [`assets/rive/README.md`](assets/rive/README.md).
- **Android application ID is still `com.example.monivo`**, the Flutter template
  default.
- **iOS widget distribution requires manual portal setup.** The App Group
  `group.com.sufiyan.monivo` must be registered in the Apple Developer portal for
  non-development builds.
- **Debug-only test notification.** Debug builds schedule an extra notification one
  minute after launch. Release builds do not.
- **No `LICENSE` file** is present in the repository.

---

## Roadmap

### Completed

| Feature | Notes |
| --- | --- |
| Multiple independent budgets with custom date ranges | Schema v3 migration |
| Per-budget Today's Safe Spending | Never combined across budgets |
| Expense tracking with categories, tags and receipts | |
| Expense history: grouping, search, filters, six sort options, paging | |
| Combined Expense View | Viewing/aggregation only |
| Reports with charts, time analytics and CSV/PDF export | Scoped to the Active Budget |
| Bills & Reminders with recurrence and payment history | |
| Smart Insights | Rule-based, on-device |
| Local notifications | Morning, evening and bill reminders |
| Biometric app lock | |
| Home screen widget | Android + iOS |
| Light / Dark / System theme with eight palettes | |
| App update checker | GitHub Releases |
| Backup, restore, export and import | |
| Motion system with reduced-motion support | |
| Animated bottom navigation | Rive icons, Material 3 bar, reduced-motion aware |
| User-created categories | Create, rename, restyle, archive, delete |
| Undo after deleting an expense | Restores the same row |
| Contextual row actions | Edit, Duplicate, Move, Delete on press-and-hold |
| Date presets and a single custom-range chip | Shared by quick filters and the filter sheet |
| Categories vs previous period report | Biggest movers against the preceding window |
| Database health check | On-demand integrity report in Settings |
| Integration tests and a schema migration test | Run on the host, no device needed |

### In progress

| Item | State |
| --- | --- |
| Database integrity service | Implemented and tested, but not yet invoked from any app flow |

### Planned

No dated commitments. Candidate areas, none of them started:

- Surfacing database integrity checks in the app.
- Removing or implementing the unused schema tables and notification preference fields.
- A distribution-ready Android application ID and an iOS signing/distribution pipeline.

---

## Contributing

1. Fork the repository and create a feature branch
   (`git checkout -b feature/your-feature`).
2. Keep business logic out of widgets — new rules belong in a use case or domain
   service, with unit tests.
3. Run the full verification set before opening a pull request:
   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   ```
4. Update `CHANGELOG.md` for user-visible changes.
5. Open a pull request. CI validates every pull request; pushes to `developer`
   produce development builds, and a push to `main` cuts a production release.

---

## Documentation

| File | Contents |
| --- | --- |
| [`CHANGELOG.md`](CHANGELOG.md) | Full version history |
| [`RELEASE_NOTES.md`](RELEASE_NOTES.md) | User-facing notes for the current release |
| [`docs/architecture/`](docs/architecture/README.md) | Why this stack, safe spending, multiple budgets, Rive navigation, offline-first, notifications, backup/restore |
| [`lib/features/budget/CALCULATION_RULES.md`](lib/features/budget/CALCULATION_RULES.md) | Every budget formula and its edge cases |
| [`docs/money_tracker_gap_analysis.md`](docs/money_tracker_gap_analysis.md) | Feature/architecture comparison against the Money-Tracker reference app and the decisions taken from it |
| [`assets/rive/README.md`](assets/rive/README.md) | Navigation artboards, licence note and how to swap the file |
| [`docs/home_screen_widget_setup.md`](docs/home_screen_widget_setup.md) | Home screen widget architecture, data keys and platform setup |
| [`docs/CI_CD.md`](docs/CI_CD.md) | Pipeline, required secrets, versioning and release process |
