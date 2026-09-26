# Rive assets

## `nav_icons.riv`

Animated icons used by the bottom navigation
(`lib/core/navigation/animated_bottom_navigation.dart`).

| Tab      | Artboard   | State machine            | Boolean input |
| -------- | ---------- | ------------------------ | ------------- |
| Home     | `HOME`     | `HOME_interactivity`     | `active`      |
| Expenses | `RULES`    | `State Machine 1`        | `isActive`    |
| Reports  | `DASHBOARD` | `State Machine 1`       | `isActive`    |
| Settings | `SETTINGS` | `SETTINGS_Interactivity` | `active`      |

Every artboard is 64×64, monochrome white on transparent, and is tinted at
runtime with the current palette (`ColorFiltered`, `BlendMode.srcIn`), so no
colour lives in the file. `DASHBOARD` is a filled glyph and is drawn at
`scale: 0.8` (see `RiveIconSpec.scale`) to match the outline icons' weight.
`SCORE` (a podium) was rejected: it collapses into a blob at 24 dp.

The app **pulses** the boolean input (true, then false after
`AppMotion.emphasized`) when a tab becomes selected. It never holds the input
true: some artboards (e.g. `RULES`) loop while held, and the steady selected
state is expressed by the bar itself (indicator, tint, label weight), which
keeps it correct after navigation and app restart.

### Origin and licence

The file comes from the Rive Community icon set that the reference project
`sufiyansakkeer/Money-Tracker` ships as `assets/rive/little_icons.riv`.
Community files are published under their author's licence (typically
CC BY 4.0). **Confirm the licence and add attribution before a store release**,
or replace the file with a bespoke export (see below).

### Replacing with a bespoke Rive file

1. Design one artboard per tab in the Rive editor, each with a state machine
   that has **one boolean input** and an `idle` state plus a short one-shot
   `active` animation. Use white shapes so the palette tint works.
2. Export as `assets/rive/nav_icons.riv` (or another name).
3. Update the artboard / state machine / input names in
   `lib/core/navigation/app_nav_destinations.dart`. Nothing else changes.

The `rive` package version is pinned to the 0.13 line (pure-Dart runtime, no
build-time native downloads). Files exported with Rive editor features newer
than that runtime (Layouts, Data Binding, Scripting) need `rive` ≥ 0.14 and a
rewrite of `rive_nav_icon.dart`, which is the only file that imports the
package.
