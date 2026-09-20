# Money Tracker → Smart Monivo gap analysis

**Date:** 2026-09-20
**Target:** `budget_tracker` (package `monivo`, "Smart Monivo", v1.2.3+7, branch `feature/advanced-ui`)
**Reference:** `Money-Tracker` (package `money_track`, v1.0.1+1, last commit `09fd075`, Firebase/Hive/Rive)

Baseline of the target before any change: `flutter analyze` clean, `flutter test` 630 passing.

---

## 0. Outcome (what was actually built)

This document was written as an audit and a plan before any code changed. It is
kept as the record of *why* each decision was taken. What follows is what
shipped, so the plan and the code do not drift apart.

**Shipped** — released as 1.3.0, see [`CHANGELOG.md`](../CHANGELOG.md):

| From the plan | Where it lives |
| --- | --- |
| P-A Foundations: one safe-spending formula, one refresh bus, one preference-key owner, dead code removed, pubspec cleaned | `lib/core/events/`, `lib/core/constants/preference_keys.dart`, `BudgetCalculationService` |
| P-B Database: foreign keys enforced, composite index, SQL aggregation, CSV round trip, migration test | `lib/core/database/app_database.dart` (v5), `test/core/database/app_database_migration_test.dart` |
| P-C Rive navigation | `lib/core/navigation/`, [`architecture/rive_navigation.md`](architecture/rive_navigation.md) |
| P-D Category management | `lib/features/categories/` |
| P-E Transaction experience: undo delete, long-press actions, duplicate, move, date presets, press feedback | `lib/features/expenses/presentation/` |
| P-F Dashboard polish: weekly line, sorted bills, press feedback | `lib/features/dashboard/presentation/` |
| P-G Reports: category period comparison | `lib/features/reports/` |
| P-H Settings & notifications: database health check, notification freshness, live subtitles | `lib/features/settings/`, `lib/core/notifications/` |
| P-I Integration tests | `test/integration/` |
| P-K Documentation | [`architecture/`](architecture/README.md), README, CHANGELOG, release notes, TODO |

**Bugs the work uncovered**, none of which came from the reference app — they
were found by writing the tests the plan called for:

1. Moving an expense between budgets never credited the budget it left, so that
   budget stayed short by the amount permanently.
2. Foreign keys were declared but never enforced, so orphaned rows were
   possible; the v5 migration repairs existing databases before switching
   enforcement on.
3. Three different implementations of Today's Safe Spending could show
   different numbers on different screens.
4. A CSV exported by the app could not be imported back into it.
5. The morning notification's text was frozen at schedule time.
6. Dashboard "upcoming bills" were not sorted by due date.
7. Recurring bill totals ignored the recurrence interval.

**Not done, deliberately** — see §13 for the reasoning: income tracking, a
currency converter, a speed-dial FAB, a generic `Result<T>` refactor, and
changing the Android application id. These are recorded in
[`TODO.md`](../TODO.md) so they are not re-litigated.

---

## 1. Purpose and method

Both repositories were read in full (source, assets, tests, CI, Android/iOS config).
The reference Rive assets were loaded with the Rive runtime in a throw-away project to
enumerate artboards, state machines and inputs, render every icon, and observe state
machine behaviour over time. Results are in §8.

Every difference is classified as one of:

| Action | Meaning |
| --- | --- |
| **KEEP** | Smart Monivo's implementation is already equal or stronger. Leave it. |
| **IMPROVE** | Both have it; Smart Monivo's is the stronger base and gets the reference's good idea folded in. |
| **IMPLEMENT** | Present (or better) in Money Tracker, missing in Smart Monivo, and worth having. Built in Smart Monivo's architecture. |
| **REPLACE** | Smart Monivo's implementation is swapped for a new one (only where clearly justified). |
| **REJECT** | Not adopted: redundant, lower quality, or conflicts with Smart Monivo's product direction. |

## 2. Executive summary

Money Tracker is a compact 170-file app (Hive, Firebase Auth, Syncfusion, Rive nav, one
trivial test). Smart Monivo is a considerably more mature product (Drift, Clean Architecture,
630 tests, design-system + motion tokens, bills, notifications, biometrics, widget, backup).
In almost every functional area Smart Monivo is ahead, so the bulk of this exercise is
**not** feature import. What Money Tracker genuinely contributes:

1. **Rive animated bottom navigation** — the one explicit product requirement (§8).
2. **Transaction interaction patterns** — press-scale rows, long-press contextual sheet,
   date-preset filter pill with a smart label, and the "return `true` on Apply" sheet contract.
3. **Category management** — user-created categories (Smart Monivo has a `Categories` table
   with `isSystem` but no UI or repository method to add one).
4. **A few engineering hygiene ideas** — a single generic refresh bus, live settings
   subtitles, and a reminder that formulas must have exactly one home.

Everything Firebase/Hive/Syncfusion/Lottie/GoogleFonts-shaped is rejected: it conflicts with
offline-first, Drift, Material 3 without UI kits, or the "minimal dependencies" rule.

The audit also surfaced **internal Smart Monivo debt** that the "no duplicates / no
regressions" rules oblige us to fix while we are in the code (§9): three different
"today's safe spending" formulas, three copies of the `active_budget_id` key, an orphaned
`ResetMonthUseCase`, two update dialogs, dead widgets, an FK pragma that is never enabled,
a missing composite index, and stale docs/version strings.

## 3. Stack snapshot

| Concern | Money Tracker | Smart Monivo | Verdict |
| --- | --- | --- | --- |
| State | flutter_bloc 9, get_it 8 | flutter_bloc 8.1, get_it 8 | KEEP (bump bloc only if needed; not required) |
| Persistence | hive_ce (denormalised copies of Category inside Transaction) | Drift/SQLite v4, FKs declared, 4 indexes | KEEP Drift; IMPROVE schema (§9) |
| Navigation | imperative `Navigator` + `page_transition`, string routes unused | GoRouter `StatefulShellRoute`, custom `FadeThroughBranchContainer`, typed transitions | KEEP |
| Auth | Firebase email/password, rethrows on init failure | Biometric app lock, offline-first | REJECT Firebase |
| Charts | Syncfusion (`SfCircularChart`, `SfCartesianChart`) | fl_chart with `ChartReveal` | KEEP fl_chart |
| Fonts | google_fonts Poppins | Material default + custom `TextTheme` | KEEP (no runtime font download) |
| Icons | SVG assets via svg_flutter | Material rounded icons, `CategoryVisuals` | KEEP |
| Nav icons | Rive (`rive` 0.13.20) | `NavigationBar` with `TweenAnimationBuilder` cross-fade | **REPLACE** with Rive bar (§8) |
| Tests | 1 smoke test | 630 unit/bloc/widget tests | KEEP; ADD tests for new work |
| CI | analyze/test/build APK+AAB, GitHub release | analyze/format/test/coverage, signed release, iOS no-codesign | KEEP |

## 4. Matrix A — Features

| Area | Money Tracker | Smart Monivo | Action | Priority | Why |
| --- | --- | --- | --- | --- | --- |
| Authentication / security | Firebase email+password; `AuthWrapper`; no biometrics | Biometric app lock (`AppLockBloc`, `BiometricGateScreen`), relock on background | **REJECT** Firebase, **KEEP** biometrics | — | Offline-first product; accounts add a network dependency and a privacy surface with no user benefit here. |
| Dashboard | Balance count-up, income/expense tiles, full transaction list | Safe-spending hero, budget overview, insights, recent expenses, upcoming bills, quick actions, per-budget limits | **KEEP**, polish in Phase 9 | Medium | Monivo's dashboard is richer and already animated; only entrance/refresh behaviour needs tightening (§9 D-6). |
| Expenses | Add/edit/delete with mandatory description; no search | Full CRUD, receipts, tags, time, validation, history with search/filter/sort/pagination/combined view | **KEEP** | — | Strictly stronger. |
| Income | `TransactionType.income`, green form, totals | None. Budgets are envelopes: the budget amount *is* the money available | **REJECT** (defer; product decision) | — | An income ledger changes the meaning of "remaining" and "safe spending" (does income top up the envelope?). Adding it silently would fork the calculation engine the product is built on. Documented as a roadmap decision in §13; a lightweight "top-up budget amount" already exists via edit. |
| Transactions (unified ledger) | Single `TransactionEntity` for both types | Expenses only | **REJECT** | — | Follows from the income decision. |
| Categories | Fixed 6 icons, user can add a name (expense only), delete broken (key mismatch), no edit | 13 seeded, `Categories` table with `isSystem`, no create/edit/archive UI | **IMPLEMENT** category management | **High** | Real gap on both sides; Monivo has the schema already. Build: repository methods, use cases, `CategoryBloc`, a management screen under Settings, icon+colour picker, archive (not delete) for categories with expenses. |
| Budgets (multiple) | Per-category budgets, weekly/monthly anchored to start date | Multiple independent budgets with custom start/end, active budget, phases | **KEEP** | — | Monivo's is the core differentiator. |
| Budget periods | Weekly/monthly recurring, month-end bug | Arbitrary date range, "Start new period" | **KEEP** | — | |
| Daily spending limit / safe spending | None | Per-budget `(remaining + spentToday) / remainingDays` | **KEEP**, **IMPROVE** consistency | **High** | Three variants exist in Monivo (§9 D-1). One formula, one place, docs updated. |
| Reports / charts | 5 chart types switchable; totals card; "last N days" only | Overview, donut+ranked list, daily line, weekly/monthly bars, weekly comparison, weekday patterns, trend, insights, CSV/PDF | **KEEP**; **IMPLEMENT** category period comparison | Medium | Chart-type switching adds UI noise for the same data (rejected). A per-category "this period vs previous" delta is a real analytic gap and cheap with the existing comparison window. |
| Analytics | Sum by day / by category | `AnalyticsService` (trend, consistency, weekday, weekend share) | **KEEP** | — | |
| Bills / reminders | None (notification service is commented out) | Full bills feature with recurrence and reminders | **KEEP** | — | |
| Notifications | Dead code | Daily safe-spending notifications, bill reminders, custom icon/colour | **KEEP**; **IMPROVE** body freshness | Medium | Morning notification body is computed at schedule time (§9 D-9). |
| Recurring transactions | None | Recurring *bills* yes; `RecurringExpenses` table unused | **KEEP** as is | — | Not a Money Tracker gap. Dead table stays (removing needs a migration with no user benefit). |
| Search | None | Debounced search across note/category/tags | **KEEP** | — | |
| Filtering | Type, sort, 7 date presets (today…this year, custom) | Category, from/to, min/max, tags, receipt-only, quick chips Today/Week/Month | **IMPROVE** | Medium | Port the *date preset* model (Yesterday, Last week, This year, Custom) and the smart range label ("12 Mar – 15 Mar") into Monivo's filter; keep everything else. |
| Sorting | Newest/oldest | 6 options | **KEEP** | — | |
| Date selection | `showDatePicker`, race bug | Today/Yesterday shortcuts + picker | **KEEP** | — | |
| Currency / multi-currency | 8 hard-coded rates, converter sheet, symbol only | 10 currencies, per-budget currency, no conversion | **REJECT** converter; **KEEP** per-budget | — | Fake static rates presented as conversion are misleading. Per-budget currency is honest. |
| Export / import / backup / PDF / CSV | `share_plus` declared, unused | CSV, JSON, PDF, versioned backup/restore | **KEEP**; **IMPROVE** CSV round-trip | Low | Monivo's own CSV export and import disagree on columns (§9 D-12). |
| Biometric lock | None | Yes | **KEEP** | — | |
| Settings | Profile tiles with live subtitles (currency, theme) | Sectioned settings screen | **IMPROVE** | Low | Show current value as subtitle on palette/currency/notification tiles (already partly done). |
| Themes / palettes / dark / system | 6 palettes × light/dark, `ThemeLoading` flash on switch | 8 palettes with `AppColorTokens.lerp`, animated theme switch | **KEEP** | — | |
| Onboarding | 3 Lottie pages, collects nothing | 7 steps collecting budget/currency/dates | **KEEP** | — | Lottie would be a new dependency for decoration only. |
| Empty / error / loading states | Plain text, spinner | `EmptyState`, `ErrorState`, skeletons everywhere | **KEEP** | — | |
| Offline behaviour | Requires Firebase init to start | Fully offline | **KEEP** | — | |
| App update handling | None | GitHub releases checker | **KEEP**; dedupe dialogs | Low | §9 D-5. |
| Home-screen widget | None | Android + iOS | **KEEP** | — | Verify in Phase 16. |

## 5. Matrix B — UI / UX

| Area | Money Tracker | Smart Monivo | Action | Priority | Why |
| --- | --- | --- | --- | --- | --- |
| Bottom navigation | Floating pill, Rive icons pulsed on tap, label weight/size change, global controller lists | M3 `NavigationBar`, icon cross-fade, re-tap pulse, haptics, reduced-motion aware | **REPLACE** with `AnimatedBottomNavigation` (Rive) | **High** | Explicit requirement. Keep Monivo's behaviours (haptics, re-tap pops to root, reduced motion, 4 tabs, labels) and its M3 identity; add Rive icon motion and a proper selected indicator. Detailed design in §8. |
| Navigation transitions | `page_transition` package, mixed directions | Typed shared-axis / fade-scale / fade-through, reduced-motion aware | **KEEP** | — | |
| Tab transition | Fade + scale 0.95→1 on every switch | `FadeThroughBranchContainer` (opacity + 0.98 scale) | **KEEP** | — | Same idea, already present and state-preserving. |
| Micro-interactions: buttons | `AccessibleButton` w/ tooltip | `Pressable`, `PrimaryButton` loading morph | **KEEP** | — | |
| Cards | Hover-scale card (web-ish) | `AppCard` animated border/colour | **KEEP** | — | |
| Forms / inputs | Full-bleed coloured scaffold, 70 px hero amount, no input formatter | `ExpenseAmountField` (formatter, focus glow), sticky save with success morph | **KEEP**; **IMPROVE** amount feedback | Medium | Add subtle scale/colour tick on amount change and category selection; keep M3 look. |
| Category selection | Bottom sheet list with checkmark | `ChoiceChip`s with `AnimatedScale` | **KEEP** | — | |
| Transaction rows | Press-scale 0.98 with border tint, long-press options sheet | `ExpenseHistoryItem` with `FadeSlideIn`, `Dismissible` delete | **IMPROVE** | **High** | Add press feedback (`Pressable`) and a long-press contextual sheet (Edit / Duplicate / Move / Delete). |
| Delete flow | Long-press → sheet → confirm dialog, no undo | Swipe → confirm dialog; details → confirm; no undo | **IMPROVE** | **High** | Replace confirm-dialog-on-swipe with immediate delete + SnackBar **Undo** (5 s), keep confirmation only for the details-screen button. Fewer dialogs, as required by Phase 8. |
| FAB | Speed-dial (Expense / Income) with scrim | Single extended `AppFab` | **REJECT** speed-dial | — | With no income type there is one primary action; a speed-dial adds a tap. Bills are one tap away in Quick actions. |
| Budget cards | `LinearProgressIndicator` not animated, 70/90 % colours | `AppProgress` tweened value+colour, count-ups, phase chip | **KEEP** | — | |
| Charts | Syncfusion defaults | `ChartReveal` sweep, placeholders, dark-mode safe | **KEEP** | — | |
| Lists | `ListView.separated`, no grouping | Grouped by day with animated totals, pagination | **KEEP** | — | |
| Filter UX | Pill showing current range; sheet returns `true` on Apply | Filter button + active-filter chips | **IMPROVE** | Medium | Add the date-range pill/preset sheet; keep chips. |
| Search UX | None | Debounced search bar | **KEEP** | — | |
| Dialogs / sheets | `showModalBottomSheet` with drag handle | `AppBottomSheet`, `AppDialog` (scale+fade) | **KEEP** | — | |
| Snackbars | Global key `showSnack` extension | Floating themed SnackBars | **KEEP**; add Undo actions | High | |
| Pull-to-refresh | None | `RefreshIndicator` on dashboard/history/budgets | **KEEP** | — | |
| Theme switching | Rebuilds through `ThemeLoading` (flash) | Animated lerp | **KEEP** | — | |
| Accessibility | `Semantics`/`Tooltip` helpers, live region | Broad `Semantics`, headers, live regions, 48 dp targets | **KEEP**; audit in Phase 14 | Medium | `Shimmer` ignores `AppMotion.isReduced` (§9 D-7). |
| Responsive layouts | Fixed widths (190 px tiles) | `contentMaxWidth 640`, adaptive columns | **KEEP** | — | |
| Empty states | Text only | Illustrated with actions | **KEEP** | — | |

## 6. Matrix C — Architecture

| Area | Money Tracker | Smart Monivo | Action | Priority | Why |
| --- | --- | --- | --- | --- | --- |
| Layering | Clean-ish; `features/*` + shared `domain/`, `data/` | Clean Architecture per feature | **KEEP** | — | |
| Use-case base | `UseCase<R, P>` with nullable params → `ArgumentError` | Per-feature use cases with typed inputs | **KEEP** | — | |
| Result / failure types | One generic `Result<T>` + `Failure` hierarchy | Five sealed result types (`BudgetResult`, `ExpenseResult`, …) with identical shape | **KEEP** (deliberately) | Low | A cross-feature generic would touch every bloc and test for no user-visible gain. Note as roadmap. |
| Cross-feature refresh | Bloc re-dispatch chains | Three copy-pasted singleton buses | **IMPROVE** | Medium | Collapse into one generic `RefreshBus` class with three named instances; same semantics, one implementation. |
| DI | get_it, layered init functions, blocs as factories | get_it, single 600-line function | **KEEP**; **IMPROVE** readability | Low | Split `initDependencyInjection` into per-feature registration functions. No behaviour change. |
| Models / entities | Duplicate enums domain↔model, embedded copies | Entities + Drift row mappers | **KEEP**; remove re-export duplicates | Low | §9 D-2. |
| Error handling | Double-wrapped `DatabaseFailure` strings | Typed failures per feature, user-facing mapping in state | **KEEP** | — | |
| Database | Hive boxes, open per call, no relations | Drift, FKs declared but not enforced, indexes | **IMPROVE** | **High** | Enable `PRAGMA foreign_keys`, add `(budgetId, date)` index in migration v5, SQL `SUM`/`COUNT` for totals, migration tests. |
| Navigation | Widget-in-state pages list | GoRouter shell, transitions | **KEEP** | — | Rive stays out of the router; `AppShell` only swaps the bar widget. |
| Services | `CircuitBreaker` (unused), `BudgetNotificationService` (dead) | Notification/biometric/backup/widget services | **KEEP** | — | Circuit breaker has no remote call to protect. |
| Testing architecture | None | `bloc_test`, mockito, in-memory Drift helper | **KEEP** | — | |
| Code organisation | Stray files (`firestore.rules`, empty `group_model.dart`) | Dead widgets, orphaned use case, placeholder file | **IMPROVE** | Low | §9. |

## 7. Matrix D — Engineering

| Area | Money Tracker | Smart Monivo | Action | Priority | Why |
| --- | --- | --- | --- | --- | --- |
| Unit / bloc tests | None | ~615 | **KEEP**; **ADD** for every new unit | High | |
| Widget tests | 1 smoke | Forms, history, settings tiles, nav shell | **ADD** nav bar, category screen, dashboard hero, reports cards | High | Reports/dashboard widgets are currently untested. |
| Integration tests | `integration_test` dep, no tests | none, no `integration_test/` dir | **IMPLEMENT** critical flows | Medium | Expense create/edit/delete/undo, budget switch, safe-spending, report load — as widget-level integration tests with in-memory Drift (runnable in CI without a device). |
| CI/CD | analyze/test/apk/aab; release on tag | analyze/format/test/coverage; signed release with version bump | **KEEP** | — | Rive needs no CI change (pure-Dart runtime chosen, §8.4). |
| Logging | 113 `log()` calls | `debugPrint` guarded | **KEEP** | — | |
| Performance | Per-tile `AnimationController`, budgets recomputed in build with logging | Tokenised implicit animations, memoised calc service, Dart-side aggregation | **IMPROVE** | Medium | SQL aggregation; audit rebuilds in Phase 13. |
| Caching | In-bloc list | Memoised calc, in-memory pagination | **KEEP** | — | |
| Offline-first | No (Firebase) | Yes | **KEEP** | — | |
| Release config | Debug signing, `com.example.money_track` | Signed release via secrets, but `com.example.monivo` app id | **KEEP**; flag app id | — | Changing the application id breaks the widget provider name, deep links and existing installs; leave for a deliberate release decision (documented in README already). |
| Android config | minSdk 24, Java 17 | minSdk 23, Java 11, desugaring | **KEEP** | — | `rive` 0.13 supports minSdk 21+. |
| iOS config | 15.0 | Info.plist permissions present | **KEEP** | — | |
| Docs | README overstates features | README honest; `docs/CI_CD.md`, widget doc, `CALCULATION_RULES.md` stale | **IMPROVE** | Medium | Phase 15. |

## 8. Rive bottom navigation — reference analysis and Smart Monivo design

### 8.1 What Money Tracker does (facts)

- Package `rive: ^0.13.4` (locked 0.13.20). Widgets: `RiveAnimation.asset(src, artboard:, onInit:)`;
  `StateMachineController.fromArtboard(artboard, name)`; `controller.findInput<bool>('active') as SMIBool`.
- Assets: `assets/rive/animated_icon_rive.riv` (used) and `assets/rive/little_icons.riv` (unused).
- Items (`bottom_navigation_list.dart`): HOME/`HOME_interactivity`, LIKE/STAR/`STAR_Interactivity`, USER/`USER_Interactivity`.
- On tab change (`bottom_navigation_page.dart:_onTabChanged`): `riveIconInputs[index].change(true)` then
  `false` after 150 ms (a pulse). Selected state is shown only by label weight/size; the icon has
  no persistent selected look. Controllers and inputs live in **global mutable lists** filled in
  `onInit` order — an ordering race if artboards load out of order.
- Page switch: 400 ms fade + 0.95→1 scale via `AnimationController` around the page.
- No reduced-motion handling, no semantics, no keys, no tests.

### 8.2 What the assets contain (measured)

Both files share one structure per icon: 64×64 artboard, one state machine, **one boolean input**,
animations `idle` and `active`. Monochrome white shapes on transparent → tintable with
`ColorFiltered(BlendMode.srcIn)`, so palette colours apply without touching the file (Rule 6).

| File | Artboard | State machine | Input | Fit for Monivo tab |
| --- | --- | --- | --- | --- |
| little_icons.riv | `HOME` | `HOME_interactivity` | `active` | **Home** |
| little_icons.riv | `RULES` (clipboard checklist) | `State Machine 1` | `isActive` | **Expenses** |
| little_icons.riv | `SCORE` (rising podium bars) | `State Machine 1` | `isActive` | **Reports** |
| little_icons.riv | `SETTINGS` (gear) | `SETTINGS_Interactivity` | `active` | **Settings** |
| little_icons.riv | `DASHBOARD` (four dots) | `State Machine 1` | `isActive` | alternative for Reports |
| animated_icon_rive.riv | HOME, SETTINGS, SEARCH, TIMER, BELL, CHAT, USER, LIKE/STAR, REFRESH/RELOAD, AUDIO | `*_Interactivity` | `active` | no Expenses/Reports match |

State-machine behaviour when the input is **held** true (sampled every 100–500 ms for 3 s):

- `HOME`: plays ≈1 s, settles into a distinct "active" pose, returns to idle when released. A true toggle.
- `RULES`: keeps changing for the full 3 s and had not returned to idle 1.5 s after release → **loops while held**.

Conclusion: holding the input would give inconsistent results per icon and a permanently looping
Expenses icon (explicitly forbidden). The bar therefore **pulses** the input (true on selection,
false after the pulse window) and expresses the steady selected state itself.

### 8.3 Constraints discovered

1. **`.riv` files cannot be authored here.** They are produced by the Rive editor. The plan ships
   the reference project's `little_icons.riv` (renamed `assets/rive/nav_icons.riv`) because it has
   matching artboards for all four tabs. The widget takes an asset descriptor per destination so a
   bespoke Smart Monivo file exported later drops in without code changes. Attribution: the file is
   a Rive Community asset already used by the author's reference project; a `assets/rive/README.md`
   records origin and the swap procedure — the owner should confirm the licence before store release.
2. **`rive` 0.13.x cannot run inside `flutter test`.** Importing a file calls into `rive_common`'s
   FFI layout engine (`makeYogaStyle`), which throws `ArgumentError: Failed to lookup symbol` on the
   host VM. `rive` 0.14.x (rive_native) supports host tests only after downloading native libraries
   (`dart run rive_native:setup --platform macos`) and downloads binaries during every
   `flutter build` / `pod install`. Either way tests must not depend on the runtime.
3. The existing `navigation_test.dart` casts to `NavigationBar`/`NavigationDestination`. Those are
   implementation details; the behavioural invariants (four destinations, labels and order,
   `selectedIndex` follows taps, no Budget/Bills tab, `pumpAndSettle` terminates) are preserved and
   the test is updated to the new widget.

### 8.4 Decision: package version

**`rive: ^0.13.20`.**
Why: identical API to the reference (lowest risk), pure-Dart runtime on device (no build-time
binary download, deterministic CI, no Podfile changes), supports Flutter 3.32.8 and minSdk 23,
and both candidate assets import with it. Cost: it is the legacy line; 0.14 has a different API.
Mitigation: all Rive API usage is confined to one file (`rive_nav_icon.dart`) behind a small
interface, so the upgrade is a local rewrite. Documented in `docs/architecture/rive_navigation.md`.

### 8.5 Design

```
lib/core/navigation/
  nav_destination.dart            // AppNavDestination: label, key, semantic label, RiveIconSpec, Material fallback icons
  app_nav_destinations.dart       // the four Smart Monivo destinations
  rive_icon_spec.dart             // asset path + artboard + state machine + input name
  animated_bottom_navigation.dart // the bar (layout, indicator, labels, press, haptics, semantics)
  nav_icon.dart                   // NavIcon: chooses Rive or Material renderer, tint, scale
  rive_nav_icon.dart              // the ONLY file importing package:rive
  rive_file_cache.dart            // loads each .riv once, hands out artboard instances
  nav_icon_mode.dart              // InheritedWidget: NavIconMode.rive | .material (tests, fallback)
```

Behaviour:

- **Layout:** M3 bar, height `AppSizes.navBarHeight` (68) + safe area, hairline top border like
  today (Smart Monivo identity; not Money Tracker's floating pill). Four equal `Expanded` items,
  minimum 48 dp targets.
- **Selected state (steady):** stadium indicator `AnimatedContainer` (primaryContainer) grows
  behind the icon (`AppMotion.standard`, `emphasizedDecelerate`); icon tint lerps
  onSurfaceVariant → onSecondaryContainer via `TweenAnimationBuilder<Color>`; icon scale 1.0 →
  `navIconSelectedScale`; label `AnimatedDefaultTextStyle` weight 500 → 700. All from
  `selectedIndex` — deterministic after navigation, return from sub-screens and restart.
- **Rive motion (transient):** on becoming selected, `RiveNavIcon` sets the boolean input true and
  resets it after `AppMotion.emphasized`; idle otherwise. Re-tapping the current tab replays the
  pulse (and still pops the branch to root). Nothing loops.
- **Press feedback:** `Pressable`-style scale to `AppMotion.pressedScale` on down, ink ripple,
  `HapticFeedback.selectionClick()` on change (kept).
- **Reduced motion:** when `AppMotion.isReduced`, the Rive input is never pulsed (static artboard
  at idle), indicator/tint changes are instant.
- **Lifecycle:** one `RiveFile` loaded once via `rive_file_cache.dart`; each `RiveNavIcon` owns its
  `StateMachineController` and disposes it; no globals. Load failure → Material icon fallback.
- **Tests:** `NavIconMode.material` in widget tests; bar tests cover keys, order, selection,
  semantics (`selected`, `button`, labels), re-tap callback, reduced-motion path.
- **Theming:** no hard-coded colours; all from `ColorScheme`/`AppColorTokens`.

## 9. Smart Monivo internal debt found during the audit

These are not Money Tracker gaps but must be fixed under Rule 3 (no duplicates) and Phase 17.

| # | Finding | Fix |
| --- | --- | --- |
| D-1 | Three "today's safe spending" formulas: `BudgetCalculationService.buildSummary` adds today's spend back; `CalculateDailyAllowanceUseCase` and one branch of `GetSpendingTargetsUseCase` do not; `CALCULATION_RULES.md` documents the old one. | Single formula `(remaining + spentToday) / remainingDays` in the service; use cases delegate; docs updated; tests pin it. |
| D-2 | Duplicate entities/lists: onboarding re-exports of `BudgetEntity`/`BudgetModel`; onboarding's own `CurrencyItem` list duplicates `availableCurrencies`; empty placeholder `budget/domain/usecases/create_budget_usecase.dart`. | Delete re-exports and placeholder, import the canonical files, onboarding uses `CurrencyEntity`. |
| D-3 | `'active_budget_id'` literal in three files; `ResetBudgetUseCase` writes Drift directly. | One `BudgetPreferenceKeys.activeBudgetId`; reset goes through the repository. |
| D-4 | `ResetMonthUseCase` orphaned (not in DI, creates a 0-amount budget). | Delete with its test references. |
| D-5 | `UpdateDialog` and `_UpdateDialogBody` are near-identical. | One dialog widget used by both paths. |
| D-6 | Dead widgets `dashboard/widgets/summary_card.dart`, `analytics_card.dart`; `FadeSlideIn` blocks replay on every `DashboardLoaded` rebuild. | Delete dead files; entrance animation only on first load per budget. |
| D-7 | `Shimmer` checks `MediaQuery.disableAnimations` only and keeps ticking under reduced motion. | Use `AppMotion.isReduced`; stop the controller when reduced. |
| D-8 | FKs declared but `PRAGMA foreign_keys` never enabled; no `(budgetId, date)` index; v3 upgraders miss `index_expenses_budget`; totals computed in Dart. | Migration v5: enable FKs in `beforeOpen`, create composite index (idempotent `IF NOT EXISTS`), SQL `SUM` for budget/bill totals; migration test from v4 fixture. |
| D-9 | Morning notification body frozen at schedule time; `'₹'` passed as a currency *code* in `ReportInsightGenerator`; upcoming bills not sorted by due date on dashboard. | Reschedule after each expense/budget change (already have buses); pass the code; sort bills. |
| D-10 | Three identical refresh buses. | One `RefreshBus` class, three instances. |
| D-11 | `BackupService._appVersion = '1.2.2'` hard-coded; `docs/CI_CD.md` says 1.0.2; widget doc says "combined total". | Version from `package_info_plus`; docs corrected. |
| D-12 | CSV export and CSV import use different columns; import splits on `,` naively. | Import uses the `csv` package and the export's column order. |
| D-13 | pubspec: `flutter_local_notifications_platform_interface`/`local_auth_*: any` indented under `flutter_launcher_icons` (no effect); unused `freezed*`, `json_*`, `printing`, `cupertino_icons`, possibly `collection`. | Verify by grep, remove unused, delete misplaced lines. |
| D-14 | `DatabaseIntegrityService` registered but never invoked. | Run it from Settings → Data ("Check database") with a result sheet; keep it out of startup. |
| D-15 | `BudgetBloc` shows a raw error when the active budget's period has ended. | Dedicated `periodEnded`/`upcoming` state with the existing `BudgetNotRunningCard`. |

## 10. Implementation phases

Each phase ends with `flutter analyze` + `flutter test` green and a commit on `feature/advanced-ui`.

| Phase | Scope | Key files | Tests |
| --- | --- | --- | --- |
| **P-A Foundations & debt** | D-1, D-2, D-3, D-4, D-5, D-6, D-7, D-10, D-11, D-13, D-15 | budget calc service/use cases, DI, buses, dialogs, pubspec, docs | update calc tests, bus test, dialog test |
| **P-B Database** | D-8, D-12, D-14 | `app_database.dart` (v5), datasources (SQL SUM), import service, settings data card | migration test v4→v5, aggregate query tests, CSV round-trip test |
| **P-C Rive navigation** | §8.5 | `lib/core/navigation/*`, `app_shell.dart`, `pubspec.yaml`, `assets/rive/` | `animated_bottom_navigation_test.dart`, updated `navigation_test.dart` |
| **P-D Categories** | Category management | repository/datasource methods, use cases, `CategoryBloc`, `category_management_screen.dart`, icon/colour picker, Settings entry, `CategoryPicker` shows custom ones | repo, use case, bloc, widget tests |
| **P-E Transaction experience** | Undo delete, long-press sheet (Edit/Duplicate/Move/Delete), press feedback, date presets + range pill, amount/category feedback | history screen/items/bloc, `ExpenseBloc` (soft delete window), filter entities/sheet, form widgets | bloc tests for undo/duplicate, widget tests for sheet/pill |
| **P-F Dashboard polish** | Entrance only on first load, budget-switch cross-fade, sorted bills, "spent this week" line on hero, insight transitions | dashboard widgets/bloc | bloc + first widget tests for hero/overview |
| **P-G Reports** | Category period comparison card, transaction-count metric, period-switch transition, tests for chart cards | analytics service, new card, screen | analytics tests, widget tests for cards |
| **P-H Settings & notifications** | Live subtitles, D-9 reschedule, integrity check entry | settings screen, notification use cases | service/bloc tests |
| **P-I Integration tests** | `integration_test/` with in-memory Drift for the critical flows | new dir | 6 flows |
| **P-J Perf + accessibility audit** | rebuild audit, `buildWhen`, const, semantics, contrast, reduced motion sweep | targeted | — |
| **P-K Docs** | README, CHANGELOG, RELEASE_NOTES, `docs/architecture/*.md` (Drift, BLoC, Clean, GetIt, safe spending, multiple budgets, Rive nav, offline-first, notifications, backup) | docs | — |
| **P-L Final audit** | Phase 16 checklist, `flutter analyze`, `flutter test`, `flutter build apk --release`, `flutter build ios --release --no-codesign` | — | — |

## 11. Dependencies

**Add**
- `rive: ^0.13.20` (explicitly approved; pure-Dart runtime; see §8.4). Transitive: `rive_common`.

**Remove (after grep confirms zero usage)**
- `freezed`, `freezed_annotation`, `json_annotation`, `json_serializable` — no `.freezed.dart` or
  `@JsonSerializable` in `lib/`.
- `printing` — PDF export shares a file; never prints.
- `cupertino_icons` — no `CupertinoIcons` usage.
- Misplaced `: any` entries under `flutter_launcher_icons`.

**Explicitly not added:** `lottie`, `google_fonts`, `syncfusion_flutter_charts`, `page_transition`,
`smooth_page_indicator`, `svg_flutter`, `hive_ce`, `firebase_*`.

## 12. Conflicts and risks

| Risk | Mitigation |
| --- | --- |
| `rive` 0.13 is legacy; a future Flutter may break it | Isolated in one file; Material fallback renderer; upgrade note in docs. |
| Rive can't run in `flutter test` | `NavIconMode.material` in tests; runtime failure → fallback icon. |
| Community `.riv` licence | README in `assets/rive/`; owner confirms or swaps for a bespoke export. |
| Replacing `NavigationBar` changes a tested widget type | Test rewritten around behaviour (labels, order, selection, semantics). |
| Enabling `PRAGMA foreign_keys` on existing databases could reject orphan rows | Migration first repairs orphans (expenses whose budget is missing → active/first budget, matching the v3 backfill), then enables the pragma; covered by a migration test. |
| Undo-delete changes `ExpenseBloc` semantics | Delete stays immediate in the DB; undo re-creates the same row with the same id inside a transaction, so the widget/bus/dashboard stay consistent. |
| Category archive vs delete | Categories referenced by expenses are archived (hidden from pickers), never deleted; FK stays valid. |
| Unifying the safe-spending formula changes numbers shown by the daily-allowance use case | The service's add-back formula is already what the dashboard and widget display; aligning the outliers removes an inconsistency users could notice between screens. Tests updated deliberately. |

## 13. Decisions taken and points the owner may override

1. **Income tracking: not implemented.** Reason in §4. If wanted, the recommended shape is an
   `income` transaction type that *optionally* tops up the linked budget's amount, with the
   safe-spending formula unchanged — a separate, scoped piece of work.
2. **Speed-dial FAB: not adopted.** One primary action per screen.
3. **Currency converter: not adopted.** No static-rate "conversion".
4. **Rive asset:** community `little_icons.riv` from the reference repo, artboards HOME / RULES /
   SCORE / SETTINGS. Swap path documented.
5. **Rive version:** 0.13.20 (§8.4).
6. **Application id** stays `com.example.monivo` (release decision, out of scope).
7. **Generic `Result<T>` refactor** deferred (churn without user value).
