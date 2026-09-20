# Animated bottom navigation

The bottom bar is Material 3 in proportion and behaviour, with Rive-animated
icons. It lives in `lib/core/navigation/`.

```
animated_bottom_navigation.dart  the bar: layout, indicator, labels, press,
                                 haptics, semantics, reduced motion
nav_icon.dart                    picks a renderer, applies tint + scale
rive_nav_icon.dart               the only file importing package:rive
rive_file_cache.dart             loads each .riv once per process
nav_icon_mode.dart               Rive or Material renderer for the subtree
app_nav_destinations.dart        the four tabs and their artboards
nav_destination.dart             one tab: label, icons, keys
rive_icon_spec.dart              asset + artboard + state machine + input
```

## Division of responsibility

- **The router navigates.** `AppShell` (`lib/core/router/app_shell.dart`)
  owns `StatefulNavigationShell` and does nothing else: it passes
  `currentIndex` down and calls `goBranch` on tap. Re-selecting the current
  tab pops that branch to its root.
- **The bar animates.** It knows nothing about routes.

## Why the Rive input is pulsed, not held

Each artboard exposes one boolean input. The obvious design — hold it true
while the tab is selected — does not survive contact with the assets: some
artboards settle into a distinct active pose, others loop for as long as the
input is held. A looping icon in a navigation bar is exactly the "distracting
animation" the design brief rules out.

So the bar **pulses**: on becoming selected the input is set true and
released after `AppMotion.emphasized`. The steady selected state is drawn by
the bar itself — the stadium indicator grows, the icon tint lerps to the
selected colour and scales to `AppMotion.navIconSelectedScale`, the label
gains weight. Because all of that is derived from `selectedIndex`, the bar is
correct after navigating, after returning from a pushed screen, and after a
cold start, with no animation state to restore.

Re-tapping the selected tab replays the pulse (and pops the branch), so the
tap is acknowledged.

## Assets

`assets/rive/nav_icons.riv`, artboards `HOME`, `RULES`, `DASHBOARD` and
`SETTINGS`. Every artboard is 64×64 and monochrome white on transparent, so
the palette tints it at runtime with `ColorFiltered(BlendMode.srcIn)` and no
colour is baked into the file. `RiveIconSpec.scale` corrects optical weight
where a filled glyph sits next to outlines.

Provenance, licence caveat and the procedure for swapping in a bespoke export:
[`assets/rive/README.md`](../../assets/rive/README.md).

## Package version

`rive: ^0.13.20`, the pure-Dart runtime line.

- No native library is downloaded at build time, so CI and release builds stay
  deterministic and the iOS Podfile is untouched.
- Rive 0.14 moves to `rive_native`, which downloads platform binaries during
  `flutter build` and needs a separate setup step to work in tests. Files
  exported with newer editor features (Layouts, Data Binding, Scripting) will
  require that upgrade — a local rewrite of `rive_nav_icon.dart`, which is
  why every Rive API call is confined to that one file.

## Failure and test behaviour

- If the file or an artboard cannot be loaded, the icon falls back to its
  Material glyph and the failure is logged once. The bar never breaks.
- `flutter test` cannot load the Rive runtime (its native symbols are absent
  on the host VM), so `NavIconMode.defaultRenderer` returns the Material
  renderer when `FLUTTER_TEST` is set. Widget tests therefore exercise the
  real bar — layout, indicator, selection, semantics, haptics, reduced motion
  — with Material icons standing in for the artboards.

## Accessibility

Each destination is a `Semantics(button: true, selected: …, label: …)` with a
tooltip, a minimum 48 dp target, and a selection haptic on change. Under
reduced motion the Rive input is never pulsed and the indicator, tint and
label changes are instant.

## Changing the tabs

Edit `appNavDestinations` in `app_nav_destinations.dart`: label, Material
fallback icons, and the artboard/state-machine/input names. The bar, the
router branches and `test/features/navigation/navigation_test.dart` all read
from that list, so the order defined there is the order on screen.
