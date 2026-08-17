# Smart Monivo – Multi-Issue Fix & UX Improvement

## Verified Current State

- **Issue 1 (Add Expense date/time defaults):** ✅ Done — `ExpenseInitialize` event,
  `initialDate`/`initialTime` in `ExpenseState`, `ExpenseBloc` handler, and form
  wiring all present.
- **Issue 2 (Biometric Re-authenticate):** ✅ Done — persistent `Re-authenticate`
  button, `PopScope` blocking back while locked, loading state in
  `biometric_gate_screen.dart`.
- **Issue 3 (Reset Month duplicate budget):** ✅ Done via
  `reset_budget_usecase.dart` `resetCurrentMonth()` — atomic, archives existing
  budget, creates exactly one new budget, carries over `monthlyAmount`/`currency`
  so the Dashboard stays valid. The orphaned `reset_month_usecase.dart` is not
  referenced by DI/bloc.
- **Issue 4 (Smart Insights):** ✅ Done — Engine supports overspending, pace,
  progress, projected overspending, savings, and fallback behavior, with 10
  dedicated unit tests covering the business rules and edge cases.
- **Issue 5 (Currency ₹):** ✅ Done — Dashboard, expense widgets, Reports,
  report insights, chart tooltips, and PDF export use the centralized
  `CurrencyFormatter`/`MoneyText` strategy.
- **Issue 6 (View All navigation):** ✅ Done — Dashboard "View All", Budget
  Details quick actions, and the legacy Expenses history shortcut now use
  `context.go(...)` for shell tab roots, with no remaining root-tab `push` calls.

## Remaining Work

- [x] Issue 5: Convert remaining Reports widgets to use `CurrencyFormatter`.
- [x] Issue 4: Add unit tests for `GetSmartInsightsUseCase`.
- [x] Issue 6: Verify all "View All / See All" buttons use `context.go` to switch
      tabs (Expenses, Reports, Budgets) instead of pushing clones; confirm no
      duplicate standalone screens are created.
- [x] Run `flutter analyze --no-pub` (no issues found).
- [x] Run `flutter test` (298 tests passed).
- [ ] Build/run and manually verify each issue.
