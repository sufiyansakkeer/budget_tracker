# Monivo 1.3.0

## What's New

### Currency converter
- **Settings → Tools → Currency converter** converts an amount between about
  160 currencies — OMR to INR, USD to AED, EUR to OMR and so on.
- Rates are the **daily reference rates** that central banks publish, provided
  by Frankfurter. They are not live market or bank rates, and the screen always
  shows the rate's date and whether it was just fetched or saved earlier.
- **Works offline.** Once a pair has been looked up, you can keep converting it
  without a connection; the app tells you it is using a saved rate and from
  which day. Tap **Refresh rate** when you are back online.
- Change the amount as often as you like — the conversion happens on your
  phone, so it is instant and uses no data.
- Swap the two currencies with one tap. The converter remembers your last pair
  and amount.

### Your own categories
- **Settings → Expenses → Categories** lets you add categories, rename them,
  and change their icon and colour — 43 icons and 16 colours to pick from.
- Archive a category you have stopped using and it disappears from the expense
  form and the quick filters, while your old expenses keep their labels. You
  can restore it at any time.
- Categories you created can be deleted once no expense uses them. The
  built-in ones can be renamed and restyled but not deleted, so your history
  never loses its labels.

### Deleting an expense is now undoable
- Swipe an expense left and it is deleted straight away, with **Undo** offered
  for a few seconds. No dialog to dismiss first.
- Undo brings back exactly the same expense — its note, tags and receipt — and
  your budget goes back to where it was.

### Press and hold an expense
- A quick menu with **Edit**, **Duplicate**, **Move to another budget** and
  **Delete**.
- Duplicate opens the form already filled in from that expense and dated today,
  which is handy for the coffee you buy every morning.

### A livelier bottom bar
- The four tabs now have animated icons. Tapping a tab plays a short, quiet
  animation, and the selected tab stays clearly marked.
- Nothing loops or distracts, and if your device has "reduce motion" turned on,
  the animation is skipped.

### Better date filtering
- Quick date presets everywhere: **Today, Yesterday, This week, Last week,
  This month, Last month, This year**.
- A custom range now shows as a single chip, like "12 Mar – 15 Mar", instead of
  two separate From and To chips.

### More in Reports
- A new **Categories vs previous period** card shows which categories you spent
  more or less on than in the stretch just before, with the difference in money
  and percent, and a "New" marker for anything you had not spent on before.

### A clearer Dashboard
- Today's Safe Spending now also shows how the week is going: what you have
  spent against this week's share of the budget.
- Upcoming bills are listed soonest first.

### Database health check
- **Settings → Data → Database health** checks that your budgets, expenses and
  bills all still link up correctly, and tells you if anything looks off.

## Fixes

- **Moving an expense to another budget** used to leave the budget it came from
  short by that amount permanently. Both budgets are now corrected.
- **Today's Safe Spending could differ between screens** because three parts of
  the app calculated it slightly differently. There is now one calculation, and
  it is the one the Dashboard always used: today's spending counts *against*
  today's limit rather than shrinking it.
- **CSV files exported by Monivo can now be imported back into Monivo.** The
  importer also copes with columns in a different order and with notes that
  contain commas.
- **The morning notification could show an out-of-date figure** if you recorded
  expenses after it was scheduled. It now refreshes when your data changes.
- **Recurring bills due every few months** were counted as if they were due
  monthly in the totals.
- Your data is better protected: the database now enforces the links between
  expenses, budgets and categories, and repairs any that had come loose.

## Accessibility

- **Screen readers can now use the app.** Rows and cards across the app
  announced themselves as buttons but did nothing when activated; that is
  fixed everywhere, and a bill's "Mark as paid" is reachable again.
- **Text is readable.** The colour used for supporting text throughout the app
  fell below the accessibility standard, as did category colours, status
  chips, tags and several coloured figures. All of them now guarantee enough
  contrast in every palette, in light and dark.
- **Bigger touch targets** for the info buttons and a few other small controls.
- **Large font sizes** no longer clip the navigation bar or the empty states.
- **Reduce Motion** is now respected by the onboarding slides and
  swipe-to-delete as well.

## Under the hood

- **The app starts faster.** It no longer waits for the notification setup —
  including the permission prompt — before showing the first screen.
- Budget and bill totals are calculated by the database instead of in the app,
  reading settings takes one query instead of sixty, and reports read only the
  period you are looking at. Large histories stay quick.
- New end-to-end tests drive whole flows — adding, editing, deleting and
  undoing an expense, switching budgets, building a report — against a real
  database, and a migration test upgrades a real older database.
- New architecture documentation in `docs/architecture/` explains the stack,
  the safe-spending formula, how multiple budgets work, the animated
  navigation, the offline-first design, notifications, and backup and restore.
