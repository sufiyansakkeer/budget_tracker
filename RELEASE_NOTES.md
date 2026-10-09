# Monivo 1.0.0

The first release of Monivo: a budget tracker that tells you, every morning,
how much you can safely spend today. It works offline, keeps your data on your
phone, and supports several budgets in different currencies.

## What's in it

### Today's Safe Spending, at the top of Home
- One figure for the active budget: what you can spend today without running
  short before the budget ends. It stays the same all day, so spending lowers
  what is left today, not the figure itself.
- It **protects what the budget still needs**: bills linked to it that are due
  before it ends, any amount you keep aside, and a savings goal.
- Below it: how much of today's amount you have used, what you spent and what
  is left today, and the budget behind the figure — what is left, the days to
  go and where today falls in the period.
- Go over today's amount and it tells you what that costs ("about ₹21.76 less
  on each of the next 30 days"). **How it's worked out** shows the whole
  calculation, ending with tomorrow's amount if you spend nothing more today.
- **Coming up** lists the next bills and who pays them, and a **spending pace**
  chart compares your spending with an even pace once a few days have passed.
- On a tablet, Home uses two columns.

### Add an expense in seconds
- **Add expense** opens a quick sheet: a number pad, your five most used
  categories, and Today, Yesterday or another day. **More details** opens the
  full form with what you entered.
- Swipe an expense away to delete it, with **Undo** for a few seconds — your
  budget goes back to where it was. Press and hold for **Edit**, **Duplicate**
  (dated today, handy for the daily coffee), **Move to another budget** and
  **Delete**.

### Budgets and bills
- The active budget leads the Budgets screen; the others sit below, grouped by
  where they are in their period, with totals per currency.
- Bills are grouped as **Overdue**, **Due soon**, **Later** and **Paid**. Link a
  bill to the budget it is paid from and Today's Safe Spending sets it aside;
  paying it records the expense in that budget.

### Reports that lead with the answer
- What you spent, and how that compares with the same number of days just
  before. Then planned against actual for the active budget, every category
  ranked by amount (tap one to see its expenses), daily columns, your weekly
  rhythm and categories against the previous period.
- Export a report from the menu.

### A home-screen widget that fits
- Shows Today's Safe Spending for the active budget, with the same figures and
  words as Home, and an **Add expense** button.
- It **adapts to its size**: resize it on Android from a small strip with just
  the amount up to a large card with today's progress and your budget; on
  iPhone and iPad it comes in small, medium and (new) large.
- It stays readable at **large text sizes**: it switches to a simpler layout
  instead of cutting text off.
- It uses your **colour palette** and follows light and dark mode.
- After midnight it shows **Tap to update** instead of yesterday's amount.

### Your look
- **Eight palettes**, redesigned to be calm and easy to read in light and dark,
  with the same colours for "on track", "careful" and "over" in every one.
  Settings → Appearance → Color palette previews each in light and dark.
- A new typeface, Manrope, with figures that line up in every list.

### The Omani rial sign
- Amounts in Omani rials use the **new rial sign** introduced by the Central
  Bank of Oman, written as it asks: to the left of the amount, with a space —
  ⃄ 7.600. Amounts in rials are kept to the fils.
- Phones don't include the sign in their fonts yet, so Monivo brings its own.
  Notifications and the Android home-screen widget, which your phone draws
  itself, show "ر.ع." until it does.

### Currency converter
- **Settings → Expenses & tools → Currency converter** converts between about
  160 currencies using the daily reference rates central banks publish
  (provided by Frankfurter). It always shows the rate's date.
- **Works offline** for any pair you have looked up before, and remembers your
  last pair and amount.

### Your own categories
- **Settings → Expenses & tools → Categories**: add, rename and restyle
  categories (43 icons, 16 colours). Archive one you no longer use; your old
  expenses keep their labels.

### Your data
- Back up and restore, export your expenses as a spreadsheet or a data file,
  and import from either. **Settings → Data → Check database health** checks
  that budgets, expenses and bills still link up.
- Optional app lock with your fingerprint or face.

## Fixes

- Reminders no longer crash the app.
- Amounts in Omani rials can be entered to the fils (7.125), everywhere.
- Expenses, reports and bill totals use each budget's own currency, and never
  add up amounts in different currencies under one symbol.
- Symbols written in Arabic script stay in front of the amount in every
  sentence.
- Moving an expense to another budget corrects both budgets.
- Today's Safe Spending is the same on every screen, in the notification and
  on the widget.
- CSV files exported by Monivo can be imported back.
- "Add expense" on a budget's own screen records into that budget.
- Recent expenses on Home show the time they were recorded for.

## Accessibility

- Works with screen readers: every row and card does what it announces, the
  widget reads as one sentence, and amounts in rials are read as "OMR".
- Text meets contrast guidelines in every palette, in light and dark.
- Large text sizes never cut off the navigation bar, empty states or the
  widget.
- Reduce Motion is respected everywhere, including on iOS.
- Bigger touch targets for small controls.

## Under the hood

- Starts faster: it no longer waits for notification setup before the first
  screen.
- Large histories stay quick: totals are calculated by the database, and
  reports read only the period on screen.
- End-to-end, migration and golden (screenshot) tests cover the main flows and
  every redesigned screen in light and dark.
