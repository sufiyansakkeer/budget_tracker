# Home Screen Widget — Setup & Architecture

## Overview

This feature adds two capabilities to the Smart Budget Tracker:

1. **Quick View Widget** — Displays Today's Safe Spending, Spent Today, and status on the home screen.
2. **Quick Action** — "Add Expense" button that launches the app directly into the Add Expense screen.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Dart Layer                          │
│                                                     │
│  ExpenseRefreshBus ──┐                              │
│                      ├──→ WidgetRefreshListener      │
│  BudgetRefreshBus  ──┘        │                     │
│                               ▼                     │
│                     HomeWidgetService                │
│                      │                              │
│           ┌──────────┴──────────┐                   │
│           │  Uses existing      │                   │
│           │  use cases:         │                   │
│           │  • GetSpending      │                   │
│           │    TargetsUseCase   │                   │
│           │  • BudgetRepository │                   │
│           └──────────┬──────────┘                   │
│                      ▼                              │
│           HomeWidget.saveWidgetData()               │
│           HomeWidget.updateWidget()                 │
│                      │                              │
└──────────────────────┼──────────────────────────────┘
                       │ SharedPreferences
┌──────────────────────┼──────────────────────────────┐
│                  Android                            │
│                      ▼                              │
│           HomeScreenWidgetProvider                  │
│           (AppWidgetProvider + RemoteViews)          │
│                      │                              │
│              Reads SharedPreferences               │
│              Renders widget UI                      │
│              PendingIntent → MainActivity           │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                  iOS                                 │
│                      ▼                              │
│           MonivoWidget (WidgetKit)                  │
│           (Swift + SwiftUI)                         │
│                      │                              │
│              Reads UserDefaults (App Group)          │
│              Renders widget UI                      │
│              Link → monivo:// URL scheme             │
└─────────────────────────────────────────────────────┘
```

---

## Data Flow

### Widget Data Keys

All widget data is stored in SharedPreferences with these keys:

| Key | Type | Description |
|-----|------|-------------|
| `home_widget_daily_safe` | String (double) | Combined daily safe spending across active budgets |
| `home_widget_spent_today` | String (double) | Combined amount spent today across active budgets |
| `home_widget_status` | String | `on_track`, `over:{amount}`, `no_budget`, or `error` |
| `home_widget_remaining` | String (double) | Combined remaining budget |
| `home_widget_remaining_days` | String (int) | Minimum remaining days across active budgets |
| `home_widget_currency` | String | Currency code (e.g., `INR`, `USD`) |
| `home_widget_has_budget` | String | `true` or `false` |
| `home_widget_last_updated` | String | ISO 8601 timestamp of last update |
| `home_widget_quick_action` | String | Route path for quick action navigation |

### When Widget Updates

The widget refreshes when:
- An expense is created, updated, or deleted
- A budget is created, updated, deleted, or switched
- The app starts (startup refresh)
- The widget's own refresh period elapses (Android: 1 hour, iOS: 1 hour)

### Safe Spending Calculation

The widget does NOT duplicate any calculation. It uses:

```dart
// GetSpendingTargetsUseCase.callPerBudget()
// → Per-budget daily limits (same as dashboard)
// → Combined across all active budgets
```

The formula used (via existing `BudgetCalculationService`):

```
Daily Safe Spending = (Monthly Amount - Total Spent) ÷ Remaining Days
```

---

## Android Requirements

The `home_widget` package requires `androidx.work:work-runtime-ktx:2.11.2`, which mandates **minSdk ≥ 23** (Android 6.0 Marshmallow). The project's `build.gradle.kts` has been updated to:

```kotlin
minSdk = 23  // Required by home_widget's androidx.work dependency
```

Android 5.0–5.1 (API 21–22) devices are no longer supported. This is consistent with the Flutter 3.32.8 ecosystem and Google Play's device distribution.

## Android Setup (Automatic)

The Android widget is fully configured via files:

- `android/app/src/main/kotlin/com/example/monivo/HomeScreenWidgetProvider.kt`
- `android/app/src/main/res/layout/widget_spending_view.xml`
- `android/app/src/main/res/xml/widget_spending_info.xml`
- `android/app/src/main/AndroidManifest.xml` (updated with receiver)

**No manual Xcode/IDE configuration needed for Android.**

To add the widget to the home screen:
1. Long-press on the home screen
2. Tap "Widgets"
3. Find "Budget Tracker"
4. Drag to home screen

---

## iOS Setup

The iOS WidgetKit extension is configured programmatically:

- `ios/MonivoWidget/MonivoWidget.swift` — Widget implementation
- `ios/MonivoWidget/Info.plist` — Extension configuration
- `ios/MonivoWidget/MonivoWidget.entitlements` — App Group entitlement
- `ios/Runner/Runner.entitlements` — Main app App Group entitlement
- `ios/Podfile` — Updated with MonivoWidget target

### App Group Configuration

Both the main app and widget extension share data via App Group `group.com.sufiyan.monivo`. The entitlements files are created automatically.

**Critical:** The App Group must be registered in the Apple Developer portal for distribution builds. For development, Xcode auto-provisions it.

### Dart-Side Initialization

The `main.dart` calls `HomeWidget.setAppGroupId('group.com.sufiyan.monivo')` at startup. This is required before any `saveWidgetData` calls on iOS — without it, all iOS data sharing fails silently.

### Build and Run

1. Select a physical iOS device (widgets don't work in simulator)
2. Build and run
3. Long-press on home screen
4. Tap "+" → Find "Budget Tracker" widget
5. Add to home screen

---

## Cold Start & Warm Start Navigation

### Cold Start (App Fully Closed)

1. User taps widget's "Add Expense" button
2. Android: `PendingIntent` launches `MainActivity` with `home_widget_action=add_expense` extra
3. iOS: `Link` opens `monivo://add-expense` URL scheme
4. `main.dart` checks `HomeWidget.initiallyLaunchedFromHomeWidget()`
5. Route is stored via `setPendingWidgetRoute()`
6. GoRouter redirect detects the pending route
7. App navigates to `/app/expenses/add`

### Warm Start (App Backgrounded)

1. User taps widget
2. App comes to foreground
3. Same flow as cold start

### Intent Handling

On Android, the intent extra `home_widget_action` is set by the widget provider:

```kotlin
putExtra("home_widget_action", "add_expense")
```

On iOS, the URL scheme `monivo://add-expense` is used via WidgetKit's `Link`.

---

## Midnight / Day Change

The widget refreshes automatically:
- **Android**: `updatePeriodMillis="3600000"` (1 hour) triggers periodic refresh
- **iOS**: Timeline policy `.after(nextUpdate)` with 1-hour interval
- **On app start**: Widget data is refreshed immediately

After midnight, the next app launch or periodic refresh will show the new day's data.

---

## Multiple Budgets

The widget shows a **combined total** across all active budgets:

```
Today's Safe Spending     ← Combined across all active budgets
₹1,300

Spent Today               ← Combined across all active budgets
₹860

On Track                  ← Based on combined spending vs. combined limit
```

This matches the existing dashboard behavior (the legacy `SpendingTargetEntity`).

---

## Error Handling

| State | Widget Display |
|-------|---------------|
| No active budget | "Open app to set up a budget" with empty values |
| Data fetch error | "Open app to refresh" with empty values |
| Widget data unavailable | Shows last known values (from SharedPreferences) |

---

## Offline-First

The widget works entirely offline:
- All data comes from local SharedPreferences
- No network calls are made by the widget
- The Dart service reads from the local Drift database
- No cloud backend is used

---

## Testing

### Unit Tests

Run `flutter test` — all existing 595 tests pass.

### Manual Testing Checklist

- [ ] Widget displays correct spending data on home screen
- [ ] Widget updates after adding an expense
- [ ] Widget updates after editing an expense
- [ ] Widget updates after deleting an expense
- [ ] "Add Expense" button launches app into Add Expense screen
- [ ] Widget shows "On Track" when under daily limit
- [ ] Widget shows "Over" amount when over daily limit
- [ ] Widget shows empty state when no budget exists
- [ ] Widget updates at midnight (new day)
- [ ] Multiple budgets show combined totals correctly
- [ ] Currency symbol matches app settings
