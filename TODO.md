# Phase 9 Fix – Multi-Budget System + Complete UI Integration + Bottom Navigation

## Development Steps

- [x] 1. Create AppShell with Material 3 NavigationBar (5 tabs)
- [x] 2. Rewrite GoRouter with StatefulShellRoute preserving per-tab stacks
- [x] 3. Update all existing navigation call sites to new `/app/...` routes
- [x] 4. Refactor Onboarding to 7 steps (Name, Amount, Currency, Start Date, End Date, Confirmation) creating a custom-date budget
- [x] 5. Make Onboarding set the created budget as active and navigate to `/app/home`
- [x] 6. Add active-budget selector to Dashboard header
- [x] 7. Fix DashboardLocalDataSourceImpl.getRecentExpenses to scope by budget period (not calendar month)
- [x] 8. Make Expense form budget-aware (budget picker, currency, date-in-period validation)
- [x] 9. Set expense.budgetId from selected budget; never create without budget
- [x] 10. Scope Expense History & Expenses list to active budget (history done; list pending)
- [x] 11. Show Budget in Expense Details + add "Move to another budget"
- [x] 12. Add budget switcher to Reports + refresh on budget switch
- [x] 13. Fix single-budget assumptions (reset_budget, reset_month, onboarding)
- [x] 14. Make Notifications budget-aware
- [ ] 15. Add/update tests for multi-budget, budget scoping, date validation, navigation
- [ ] 16. Run `flutter analyze`, `flutter test`, `flutter build` and fix issues
