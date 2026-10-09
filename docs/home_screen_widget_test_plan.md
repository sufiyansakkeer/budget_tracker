# Home Screen Widget — Test Plan & Results

Companion to [home_screen_widget_setup.md](home_screen_widget_setup.md).
Results below are from 9 October 2026, on `feature/monivo-premium-ui`.

---

## 1. Automated checks

### Dart (`test/features/widgets/home_widget_payload_test.dart`, 16 tests)

| Area | What is pinned |
|---|---|
| Amount | Floored and split exactly as Home's hero (`₹45.45`, symbol and minor units as separate pieces) |
| Currency | OMR keeps its own symbol and three decimals (the old widget showed `₹4`) |
| Right-to-left symbols | Figures with `د.إ` are identical to what `AppMoney` draws on Home (symbol before the digits) |
| Omani rial sign | OMR figures carry U+20C4 with its space; screen readers get "OMR" |
| Copy | Status label and tone, spent / left today, "Over by", budget line and days left all come from `SafeToSpendCopy` |
| States | On track, over today's amount (caution), over budget (critical), no budget, error, stale message |
| Colours | Every palette colour present in both modes; the accent follows the palette, status colours do not |
| Service | No active budget, active budget running, active budget not started, palette awaited on a slow start |
| Refresh | Expense, budget and bill buses and palette changes each trigger one update |

Results: 16/16 pass, also under `TZ=America/New_York` and `TZ=Pacific/Kiritimati`.
Full suite: **1,771 tests pass**; `flutter analyze`: no issues.

### Android layout matrix (debug-only `WidgetPreviewActivity`)

The preview screen builds the widget exactly as the provider does, picks the
layout for each size, and checks every result:

- **CLIPPED** — the chosen layout's content is taller than the slot;
- **CUT** — must-fit text (amount, label, status, figures) is ellipsized;
- **UNFILLED** — a card or button fill does not cover its view.

Matrix: 17 payloads (on track, over today, over budget, zero, ₹4.5 crore a
day, long OMR amounts and a long budget name, no budget, error, out of date,
all 8 palettes) × font scales 0.85, 1.0, 1.3, 1.5, 2.0 × 16 sizes from
110×50 to 412×160 dp × light and dark.

Result: **2,720 cells, 0 problems.**

Default text, Pixel-sized cells:

| Size (dp) | ≈ cells | Layout |
|---|---|---|
| 130×102 | 2×1 | COMPACT |
| 130×220 | 2×2 | COMPACT_TALL |
| 203×102, 276×102 | 3×1, 4×1 | ROW (with Add) |
| 349×102 | 5×1 | ROW_WIDE |
| 203×220 – 349×220 | 3×2 – 5×2 | STANDARD |
| 276×337 and up | 4×3+ | EXPANDED |
| 110×50, 276×60 | landscape strips | GLANCE (amount only) |

At 2.0× text the same slots step down (4×2 → ROW, 4×3 → COMPACT_TALL,
2×1 → GLANCE) and nothing is clipped.

### iOS layout renders

A scratch simulator app compiled `MonivoWidget.swift` (minus `@main`) and
rendered `WidgetBody` with `ImageRenderer`: 17 payloads × small, medium,
large and iPhone SE small/medium × Dynamic Type L (default), xxxL, AX1, AX3,
AX5 × light and dark (850 renders). Reviewed by eye. Issues found and fixed
along the way: the dot as an inline SF Symbol (placeholder glyph), OMR lines
drawn right to left, figures truncated at AX sizes, the large widget's label
truncated at AX5, the "+" icon outgrowing its circle. After the fixes no
amount or figure is truncated at any size; at AX5 the small widget shows the
amount alone, as designed.

### Builds

| Build | Result |
|---|---|
| `flutter build apk --debug` | passes |
| `flutter build apk --release` (R8, release lint) | passes; the preview activity is not in the release manifest |
| `MonivoWidget.swift`, `-application-extension`, iOS 15, device and simulator | compiles, no warnings (the previous file did not compile for its iOS 15 target: `containerBackground` is iOS 17+) |
| `xcodebuild -target MonivoWidget` | **not run to completion**: the project's Swift packages don't resolve (`home_widget` + SPM, see `TODO.md`) |

---

## 2. Device checks (Android emulator, Pixel launcher, Android 17, 480 dpi)

The widget already on the emulator's home screen reports 287×325 dp (portrait)
and 624×163 dp (landscape).

| Check | Result |
|---|---|
| Widget placed before this version, before the app is opened | "Open Monivo — Open the app to set up this widget." (no stale figures) |
| Figures match Home | ₹852.34, At risk, ₹300 spent, ₹552.34 left today, ₹24,803 left of ₹60,000, 23 days left, October Household: identical to Home |
| Layout per size | Portrait → EXPANDED, landscape → ROW_WIDE |
| User's palette (Blossom Vapor) | Applied. **Found a bug here:** on a slow cold start the widget used the Default palette (the theme was still loading); fixed by awaiting the saved theme, with a test |
| Palette change in Settings (→ Ocean, then back) | Widget redrew in the new palette within a second |
| System dark mode | Switched to the palette's dark colours with no redraw by the app |
| Font size 1.3× | Launcher triggered a redraw; EXPANDED → STANDARD; nothing clipped |
| Font size 2.0× | COMPACT_TALL; label, amount, status, track, left today and Add all intact |
| Display size 600 dpi | Widget redrawn at 229×243 dp → STANDARD (seen in the log). The Pixel launcher switches to a different home-screen grid at that density, so the widget itself wasn't on screen to photograph; the 229×243 size is covered by the matrix |
| Tap body | Opens Monivo on Home |
| Tap Add expense | Opens the Add expense screen |
| Day turned (stored `asOf` set to yesterday) | "Tap to update — Open Monivo to see today's safe spending." |
| Tap the out-of-date widget | App opens, rewrites today's figures, widget returns to EXPANDED |
| Screen reader | The widget is one node whose description is the full sentence (amount, status, budget, spent / left today); Add expense is a separate button |
| Redraw cost | Runs on its own thread. Warm: 18–81 ms. Cold process: ~0.8 s. Under heavy system load (density change): up to 4 s, never on the main thread |

Settings were restored afterwards (font 1.0, density 480, system light mode,
Blossom Vapor).

---

## 3. Not verified

- **iOS on a real home screen**: layouts were rendered in a test app, not
  placed as widgets; timeline reloads, `Link` and `widgetURL` taps, StandBy
  and tinted Home Screen modes were not exercised.
- **iOS 15 and 16**: no simulator runtimes for them here; the iOS 15 code path
  (no `ViewThatFits`) compiles but was not run.
- **Android 11 and older** (pre-12 path: single layout per orientation,
  neutral progress colours): no emulator image available.
- **Other launchers** (Samsung One UI, Nova…), foldables and tablets.
- **Refresh after adding / editing / deleting an expense and switching
  budgets on the device**: not repeated on the emulator, to avoid changing its
  data; the same refresh buses as before drive it, and the listener test
  covers the wiring.
- **The midnight alarm firing in real time**: the out-of-date state was
  checked by changing the stored date, not by waiting for midnight.
- **TalkBack / VoiceOver speech**: the accessibility tree was inspected, the
  spoken output was not listened to.

---

## 4. Manual procedure on a real device

Use a debug build for the preview tool; any build for the rest.

### Android

1. Install, open Monivo once (it writes the widget data), go home.
2. Long-press the home screen → Widgets → Monivo → drag it out (default 4×2).
3. Compare with Home: amount, status, spent / left today must match exactly.
4. Resize to 2×1, 2×2, 4×1, 4×2, 4×3 and 5×2. At each size: nothing cut off
   or overlapping; the amount is always whole; smaller sizes drop figures,
   then the status line, then the label.
5. Settings → Display → Font size: largest; then Display size: largest.
   Check the same sizes again. If a layout looks too tight, resize the widget
   slightly or open Monivo: either redraws it for the new size.
6. Toggle dark theme: colours switch without opening the app.
7. In Monivo: add an expense → widget updates; switch the active budget →
   widget shows the new budget; change Color palette → widget follows.
8. Tap the widget → Home; tap Add expense (or "+") → Add expense screen.
9. Leave the phone past midnight without opening Monivo → "Tap to update";
   tap it → today's figures return.
10. With TalkBack on, the widget reads as one sentence and Add expense as a
    button.

Layout matrix on demand (debug build):

```sh
# copy a payload JSON into the app, then render it
adb shell "run-as com.example.monivo sh -c 'mkdir -p files/widget-preview-in && cat > files/widget-preview-in/p.json'" < payload.json
printf 'payload=p.json\nscales=1.0,1.3,2.0\nnight=false\n' |
  adb shell "run-as com.example.monivo sh -c 'cat > files/widget-preview-in/request.properties'"
adb shell am start -S -n com.example.monivo/.WidgetPreviewActivity
adb shell run-as com.example.monivo cat files/widget-preview/p_light.txt   # the report
```

Without `payload`, it renders what the app last wrote.

### iOS

iOS builds need `flutter config --no-enable-swift-package-manager` (see `TODO.md`).

1. Build to a device or simulator, open Monivo once, go home.
2. Add the Monivo widget in small, medium and large.
3. Compare with Home, as above.
4. Settings → Display & Brightness → Text Size, and Accessibility → Larger
   Text (up to the largest): each family keeps the amount whole and drops
   detail in priority order; nothing is truncated with "…" except a long
   budget name.
5. Display Zoom: Larger Text — check again.
6. Dark mode; palette change in Monivo; add an expense: the widget follows.
7. Tap: small opens Home; medium "+" and large "Add expense" open Add
   expense; elsewhere opens Home.
8. Past midnight without opening the app: "Tap to update".
