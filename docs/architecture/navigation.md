# Bottom navigation

The bottom bar is Material 3 in proportion and behaviour, with icons that
cross-fade from outlined to filled. It lives in `lib/core/navigation/`.

```
animated_bottom_navigation.dart  the bar: layout, indicator, labels, press,
                                 haptics, semantics, reduced motion
nav_icon.dart                    outlined-to-filled cross-fade, tint, scale,
                                 and the selection pulse
app_nav_destinations.dart        the four tabs and their icon pairs
nav_destination.dart             one tab: label, icons, key
push_unique.dart                 context.pushUnique, which ignores a second
                                 push of the same route
```

## Division of responsibility

- **The router navigates.** `AppShell` (`lib/core/router/app_shell.dart`)
  owns `StatefulNavigationShell` and does nothing else: it passes
  `currentIndex` down and calls `goBranch` on tap. Re-selecting the current
  tab pops that branch to its root.
- **The bar animates.** It knows nothing about routes.

## State comes from the index

Everything about the steady selected state is derived from `selectedIndex`:
the stadium indicator grows from a dot, the icon tint lerps to the selected
colour, the outlined glyph cross-fades into the filled one and scales to
`AppMotion.navIconSelectedScale`, and the label gains weight. The bar is
therefore correct after navigating, after returning from a pushed screen and
after a cold start, with no animation state to restore.

The only transient motion is a short pulse (1 → 1.12 → 1 over
`AppMotion.medium`) when a tab becomes selected, replayed when the selected
tab is tapped again so the tap is acknowledged. Nothing loops.

## Icons

All four tabs use the rounded Material set so stroke weight and corners
match: `home`, `receipt_long`, `insights` and `settings`, each as an
`_outlined` / `_rounded` pair. Colours come from the `NavigationBarTheme`
that `AppTheme` builds: the indicator is held to 1.4:1 (light) / 1.8:1 (dark)
against the bar, and the selected icon to 4.5:1 against the indicator.
`test/core/theme/theme_contrast_test.dart` checks both for every palette.

Until October 2026 the icons were Rive animations. They were replaced because
the Expenses artboard (a detailed clipboard) clashed with the three line
icons, the community asset's licence was never confirmed, and the Rive
runtime could not load inside `flutter test`. Removing it also removed the
only native library that needed NDK overrides for 16 KB page sizes.

## Accessibility

Each destination is a `Semantics(button: true, selected: …, label: …)` with a
tooltip, a minimum 48 dp target, and a selection haptic on change. Text
scaling inside the bar is clamped to 1.3, like Material's own
`NavigationBar`, so labels never clip the fixed-height bar. Under reduced
motion (Android "Remove animations" or iOS "Reduce Motion", see
`AppMotion.isReduced`) the pulse never plays and the indicator, tint and
label changes are instant.

## Changing the tabs

Edit `appNavDestinations` in `app_nav_destinations.dart`: label and the
outlined/filled icon pair. The bar, the router branches and
`test/features/navigation/navigation_test.dart` all read from that list, so
the order defined there is the order on screen.
