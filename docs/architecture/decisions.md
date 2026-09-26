# Why this stack

Each choice here is load-bearing: it is cheap to describe, expensive to
reverse, and the alternatives were considered.

## Why Drift (SQLite), not Hive or shared preferences

Smart Monivo's core question is "how much can I spend today", and answering it
means aggregating expenses by budget and date range, repeatedly, on every
screen and in a background notification.

- **Relations are real here.** An expense belongs to exactly one budget and
  one category. SQLite enforces that with foreign keys, so a category cannot
  be deleted out from under history and an expense cannot point at a budget
  that no longer exists. A document store would have to denormalise a copy of
  the category into every expense, and renaming a category would then need a
  migration pass over every row.
- **Aggregation belongs in the database.** `SUM`/`COUNT` over an indexed
  `(budget_id, date)` range stays fast as history grows; loading every row
  into Dart to fold it does not. The budget datasource does exactly this.
- **Migrations are explicit and testable.** The schema is versioned, every
  upgrade step is code, and `test/core/database/app_database_migration_test.dart`
  runs a real v4 database through the upgrade and asserts the outcome.
- **Type safety.** Drift generates row classes and companions from the table
  definitions, so a column rename is a compile error rather than a runtime
  null.

Cost: a code-generation step (`dart run build_runner build`) and more
ceremony than a key-value store. Accepted deliberately.

Small, flat, non-relational values — the active budget id and the
first-launch flag — stay in `SharedPreferences` (see
`lib/core/constants/preference_keys.dart`). Everything else is in the
database, including app settings, which live in a `settings` key/value table
so they are covered by backup and restore.

## Why BLoC, not setState or a simpler notifier

- **The interesting logic is asynchronous and shared.** Adding an expense
  changes the dashboard, the budget list, reports and the home-screen widget.
  BLoC gives each of those a state machine with explicit statuses
  (`loading`, `loaded`, `refreshing`, `error`) instead of a pile of booleans.
- **States are values.** `ExpenseState`, `DashboardLoaded` and friends are
  `Equatable`, so a test asserts on a state object rather than driving a
  widget tree, and identical states do not trigger rebuilds.
- **Events are a record of intent.** `ExpenseDelete` then `ExpenseRestore` is
  readable as undo; a mutation buried in a callback is not.

Cross-feature reactions go through one small broadcast channel rather than
BLoC-to-BLoC references: `lib/core/events/refresh_bus.dart` exposes
`RefreshBuses.expenses`, `.budgets` and `.bills`. A bus carries no payload on
purpose — every listener re-reads from its repository, so nobody can act on a
stale copy.

## Why Clean Architecture layering

Each feature is `domain/` (entities, repository contracts, use cases, pure
services), `data/` (datasources and repository implementations) and
`presentation/` (BLoC and widgets). Dependencies point inwards only.

The payoff is concentrated in the budget engine: `BudgetCalculationService`
is pure Dart with no Flutter and no database, so the formula that the whole
product rests on is unit-tested directly, and the notification service, the
home-screen widget and the dashboard all call the same function rather than
each re-deriving it.

The cost is real — more files, and a trivial feature still needs a use case.
Where a use case would add nothing, the presentation layer calls the
repository through a thin `Manage*UseCase` façade instead of inventing one
class per verb.

## Why GetIt, not a dependency-injecting widget tree

`lib/core/di/injection.dart` builds the object graph once at startup:
singletons for datasources, repositories, pure services and app-wide BLoCs;
factories for screen BLoCs so each route gets a fresh one.

- Services needed outside a widget tree (notification scheduling at startup,
  the home-screen widget updater) can reach their dependencies.
- Construction order is explicit and readable top to bottom.
- Tests bypass it entirely: `test/integration/app_harness.dart` wires the same
  graph by hand against an in-memory database, which is why the integration
  tests need no device.

Provider is still used for the one genuinely tree-scoped value,
`CurrencyProvider`.

## Why no UI component package

The design system is Material 3 plus a small set of local widgets in
`lib/core/widgets/`, with tokens in `lib/core/constants/` and palettes in
`lib/core/theme/`. A component library would duplicate the theming work,
fight the palette system and add an upgrade treadmill. The one deliberate
exception is `rive`, used for the bottom navigation icons only
(see [rive_navigation.md](rive_navigation.md)).
