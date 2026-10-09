# Home Screen Widget — Setup & Architecture

The Monivo widget shows the **active budget's** Today's Safe Spending on the
home screen, with its status, what was spent and is left today, and the budget
behind it when there is room. It has an **Add expense** quick action. Budgets
are never combined.

How it was tested, and how to check it on a device:
[home_screen_widget_test_plan.md](home_screen_widget_test_plan.md).

---

## Architecture

```
Dart (lib/features/widgets/)
  RefreshBuses.expenses / .budgets / .bills ─┐
  ThemeBloc palette changes ─────────────────┼─▶ WidgetRefreshListener
  app start (main.dart) ─────────────────────┘          │
                                                        ▼
                                              HomeWidgetService
                         GetSpendingTargetsUseCase ─▶ │ (the active budget's
                         (safe-to-spend engine)       │  BudgetDailyLimitEntity)
                                                        ▼
                                              HomeWidgetPayload
                         AppMoney / SafeToSpendCopy ─▶ │ (every figure and
                         AppTheme palette colours  ─▶  │  sentence, formatted)
                                                        ▼
                         HomeWidget.saveWidgetData('home_widget_payload', json)
                         HomeWidget.updateWidget()
                                   │
           ┌───────────────────────┴───────────────────────┐
           ▼                                               ▼
Android: HomeScreenWidgetProvider               iOS: MonivoWidget (WidgetKit)
  MonivoWidgetPayload.kt  – reads the JSON        MonivoWidget.swift
  MonivoWidgetRenderer.kt – layouts, sizing,      – reads the JSON from the App
                            colours                 Group's UserDefaults
  res/layout/widget_*.xml                         – ViewThatFits per family
```

**The native widgets never compute or format money.** The Dart side reuses the
safe-to-spend engine (`GetSpendingTargetsUseCase.callPerBudget`) and formats
every figure with the same code Home uses (`AppMoney`, `SafeToSpendCopy`), so
the widget always agrees with the app: the currency's own symbol and minor
units (OMR 4.250, not "₹4"), safe amounts floored, the status words Home uses.

---

## The payload

One JSON string under `home_widget_payload`, written in one call so a widget
redraw never reads half an update. Built by `HomeWidgetPayload`
(`lib/features/widgets/home_widget_payload.dart`), which documents the shape.

| Field | Meaning |
|---|---|
| `v` | Format version (2). A widget that doesn't know the version asks the user to open the app. |
| `state` | `ready`, `noBudget` or `error`. |
| `asOf` | The day the figures are for (`yyyy-MM-dd`, local time). |
| `colors.light` / `colors.dark` | The user's palette as the app ships it: surface, ink, muted, track, accent, onAccent, divider and the status tones (`#AARRGGBB`). |
| `stale` | Title and body shown once the day has turned since `asOf`. |
| `label`, `shortLabel` | "Today's Safe Spending", "Safe today". |
| `safe` | The amount, whole and in pieces (sign, symbol, whole units, minor units) so the widget can set the symbol and minor units at half size like Home. |
| `status` | Home's status label ("On track", "Over today's amount"…) and its tone. |
| `today` | Today's track position, "Spent today", and "Left today" or "Over by". |
| `budget` | Name, days left, "₹x left of ₹y", its track position and tone. |
| `summary` | The whole widget as one sentence, for screen readers. |
| `message` | For `noBudget` / `error`: title, body and a short title. |

Older keys (`home_widget_daily_safe`, `home_widget_status`, …) are no longer
written or read. A widget placed before this version shows "Open Monivo" until
the app next starts and writes the payload.

---

## When it updates

| Trigger | How |
|---|---|
| Expense, budget or bill change | `WidgetRefreshListener` on `RefreshBuses` |
| Palette change | `WidgetRefreshListener` on the `ThemeBloc` stream |
| App start | `main.dart` |
| The day turns | Android: one inexact, non-waking alarm just after midnight, plus `TIME_SET` / `TIMEZONE_CHANGED`. iOS: a second timeline entry at midnight. Neither recomputes anything: the widget switches to "Tap to update". |
| Android periodic refresh | `updatePeriodMillis` = 1 hour (redraw only, no work in Dart) |
| Resize (Android) | `onAppWidgetOptionsChanged` redraws, re-measuring at the current font size |

Updates are serialised in `HomeWidgetService`, so a slow older update can
never overwrite a newer one.

**Why "Tap to update" after midnight:** the figures are "safe to spend
*today*". Yesterday's amount shown as today's would be misleading, and working
out today's amount needs the app's engine and database, so the widget asks to
be opened instead.

---

## Layouts

Content priority, highest first: **the amount**; what it is (label) and its
status; today's spending against it; the budget behind it; Add expense.
Smaller layouts drop from the end of that list; the amount is never cut off.

### Android (`MonivoWidgetRenderer.kt`, `res/layout/widget_*.xml`)

| Layout | Shows | Typical slot (default text) |
|---|---|---|
| `EXPANDED` | budget + days left, label, amount, status, today's track, spent / left today, budget left + track, Add expense | 4×3 and up |
| `STANDARD` | label + Add button, amount, status · budget, today's track, spent / left today | 3×2 – 5×2 |
| `COMPACT_TALL` | label, amount, status, track, left today, Add | 2×2, 2×3 |
| `ROW_WIDE` / `ROW` / `ROW_SLIM` | amount, label, status, (left today), Add button | 3×1 – 5×1 |
| `COMPACT` / `COMPACT_SLIM` | label, amount, (status) | 2×1 |
| `GLANCE_LABELLED` / `GLANCE` | label?, amount filling the slot | very small or very large text |
| `GLANCE_WHOLE` | the amount in whole units, shrunk to fit | last resort |
| `MESSAGE_FULL` … `MESSAGE_GLANCE` | title, body, Add expense — then less | no budget, error, out of date, not set up |

How a layout is chosen:

1. The provider fills every layout and **measures it in-process** with the
   device's current font scale and density (`TextView`s in sp, the same view
   tree the launcher inflates). Each layout's key is the smallest width and
   height at which its must-fit text — the amount, label, status, figures —
   shows in full. This is the "content-first" breakpoint: it moves with the
   font size, the display size, the currency and the length of the amount.
2. Android 12+: the provider passes these sized layouts to
   `RemoteViews(Map<SizeF, RemoteViews>)`, and adds one entry for each size
   the launcher reports (`OPTION_APPWIDGET_SIZES`) holding the **richest
   layout that fits** it. The launcher switches layouts itself on resize.
3. Before Android 12: the provider picks the richest layout that fits the
   reported portrait and landscape sizes, and redraws on every resize.

Colours: Android 12+ gets the palette's light and dark colours on every view
(`setColorInt` / `setColorStateList`), so the widget follows the system theme
without a redraw. Before Android 12 the widget uses the colours for the theme
in force when it was drawn, and its progress bars use neutral colours.

The widget follows the **system** light/dark setting, as widgets do, even when
the app is forced light or dark.

### iOS (`MonivoWidget.swift`)

Families: `systemSmall`, `systemMedium` and (new) `systemLarge`. Each family
lists its layouts richest first inside `ViewThatFits`, so Dynamic Type picks
the layout: larger text drops the figures, then the status, then the label.
The amount is set at its text style's size, then smaller, then in whole units
(it is a floored safe amount, so that never overstates it), and only then
scaled down — never truncated. Small widgets have no Add button: iOS sends
every tap on a small widget to its single URL.

iOS 15 has no `ViewThatFits`; there the layout is picked by text size.

---

## Taps

| Target | Android | iOS | Opens |
|---|---|---|---|
| Widget body | `PendingIntent` on `@android:id/background` | `widgetURL` | `monivo:///app/home` |
| Add expense | `PendingIntent` on `widget_add` | `Link` (medium, large) | `monivo:///app/expenses/add` |

`main.dart` resolves the URI with `resolveWidgetUriToRoute`; the cold-start and
warm-start handling (pending route, lock screen) is unchanged.

---

## Platform setup

**Android:** nothing manual. The receiver is declared in `AndroidManifest.xml`
with `res/xml/widget_spending_info.xml` (default 4×2, resizable from 2×1).
`minSdk` is 23 (`home_widget`'s WorkManager dependency).

**iOS:** the `MonivoWidget` extension shares data through the App Group
`group.com.sufiyan.monivo` (entitlements on both targets; register the group
in the Apple Developer portal for distribution builds). `main.dart` calls
`HomeWidget.setAppGroupId` before any write. iOS builds currently need
`flutter config --no-enable-swift-package-manager` (see `TODO.md`).

---

## Offline

The widget works entirely offline: the data comes from the app's local
database, and neither widget makes network calls.
