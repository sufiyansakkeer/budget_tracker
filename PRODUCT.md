# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

One Monivo design language, based on Material 3, runs on both Android and iOS (Flutter).
It does not adapt per OS. The home-screen widgets are the exception: the Android App Widget
and the iOS WidgetKit widget are native and follow their own OS.

## Users

The primary user is a salary-cycle budgeter: someone paid once per period who has to make
that money last until the next payday. They open the app at the moment of spending, often
standing at a till, and need one answer fast: how much can I spend today?

They budget a fixed amount over dates they choose themselves (a pay cycle, not necessarily
a calendar month). They want a daily guide, not a month-end report.

Secondary audience: recruiters and engineers who read the repository as a portfolio piece.
They read the README and the code, not the app's screens.

## Product Purpose

Monivo is an offline-first budgeting app. The user gives a budget an amount and a start and
end date. Monivo works out one daily number, **Today's Safe Spending**: how much can be
spent today while the money still lasts to the end of the period, after upcoming bills,
money kept aside and the savings goal are protected.

Success means two things:

1. A public launch on Google Play and the App Store, with real users keeping the daily
   habit of checking and recording.
2. A portfolio centrepiece that shows engineering and design quality.

Status: version 1.0.0+1, in active development, not yet published to any store.

## Positioning

Most expense trackers answer "what did I spend?" Monivo answers "what can I spend today?"

- The number already accounts for what is coming: linked bills due before the period ends,
  money kept aside and the savings goal are set aside first.
- The number is fixed for the day. Recording a purchase does not move the target; it is
  recalculated at midnight from what is actually left.
- Budgets run on the user's own dates. Several can run at once and their money is never
  pooled.
- Private by default: no account, no backend, no analytics. Everything is stored on the
  device.

## Operating Context

- Used in short visits, several times a day: check the number, add an expense, leave.
- Also seen without opening the app: the home-screen widget, a morning notification with
  the day's amount, and an evening summary.
- Works fully offline. The only network calls are an optional update check and the optional
  currency converter (Frankfurter daily reference rates, cached).
- Longer visits happen at the start of a period (set up a budget, link bills) and when
  reviewing (history, reports, export).
- Wide screens get a two-column Home.

## Capabilities and Constraints

**Capabilities**

- Budgets: any number, each with its own amount, currency and dates; optional kept-aside
  amount and savings goal; one active budget drives the main screens and the widget.
- Expenses: quick add (number pad, most-used categories), a full form with note, tags and
  receipt photo, swipe to delete with Undo, history with search, sort and filters.
- Bills: one-time or recurring, linkable to a budget so they are set aside in the daily
  number; reminders; "mark paid and record expense" in one step.
- Pay later tabs.
- Reports: several periods, comparisons, category ranking, CSV and PDF export.
- Currency converter; ten app currencies (INR, USD, EUR, AED, OMR, GBP, CAD, AUD, JPY, SGD).
- App lock, CSV/JSON export and import, full backup and restore.
- 13 built-in categories plus the user's own.

**Constraints**

- All figures come from two pure calculation classes (`BudgetCalculationService`,
  `SafeToSpendCalculator`). No screen repeats or alters their logic. Rules are in
  `lib/features/budget/CALCULATION_RULES.md`.
- Each budget is calculated on its own. Amounts are never combined across budgets or
  across currencies.
- Never optimistic by accident: displayed safe amounts round down; when bills cannot be
  read the breakdown says "Unavailable", not zero.
- The forecast is informational and never changes today's amount.
- Bill status is derived from dates, never stored.
- The Omani rial sign (U+20C4) ships as a bundled fallback font.

**Terminology** (use these exact terms in the interface)

- Today's Safe Spending (also "today's amount"); Left today / Over today
- Kept aside; Savings goal; Free to spend
- Statuses: On track, Spend carefully, At risk, Over budget
- Active budget; Start new budget period
- Bill statuses: Upcoming, Due today, Overdue, Paid

**Undecided**

- Languages beyond English.
- Store listing details and launch date.

## Brand Commitments

- Name: **Monivo**. Tagline: "Know what you can spend today."
- The current look is binding: the Manrope typeface, the eight colour palettes with Light,
  Dark and System modes, and the existing component set. Future work follows them rather
  than replacing them.
- Voice: plain and matter-of-fact. The app explains where its number comes from ("How it's
  worked out") instead of asking for trust.

## Evidence on Hand

- Golden screenshots of real widgets in `test/goldens/goldens/` (light and dark, 100% and
  200% text size). These are the current visual truth.
- Calculation rules and worked examples in `lib/features/budget/CALCULATION_RULES.md` and
  the README's "How Safe to Spend works".
- README feature reference, `CHANGELOG.md`, `RELEASE_NOTES.md`.

Not available, and not to be invented: user testimonials, download or usage numbers,
store ratings, press, and real-device screenshots (goldens have no device chrome).

## Product Principles

1. **One number first.** Today's Safe Spending is the answer the user came for. Everything
   else supports or explains it.
2. **Never show more than is there.** When uncertain, the app is cautious and says so.
3. **Stable through the day.** The target does not move as the user spends against it.
4. **Explain the number.** Every figure can be traced to its parts.
5. **Private and offline by default.** Nothing leaves the device unless the user asks.

## Accessibility & Inclusion

- WCAG AA text contrast in every palette and both themes, enforced by tests.
- Layouts hold at 200% text size.
- Motion respects the platform's reduced-motion setting.
- Tap-target and label guideline tests cover the main surfaces.
