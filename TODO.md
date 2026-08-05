# Phase 4 – Dashboard Implementation TODO

- [x] Analyze existing codebase & identify gaps
- [x] Create `SmartInsight` entity
- [x] Create `GetSmartInsightsUseCase` (domain)
- [x] Update `DashboardState` to include insights
- [x] Update `DashboardBloc` (map notFound → empty, load insights)
- [x] Register `GetSmartInsightsUseCase` in DI
- [x] Update `DashboardScreen` (consume insights from state, responsive, animations, accessibility)
- [x] Add animations to `BudgetProgressCard`
- [x] Add animations + semantics to `SummaryCard`
- [x] Fix existing broken `dashboard_bloc_test.dart` (constructor changes)
- [x] Update `widget_test.dart` smoke test (animated dashboard no longer uses placeholder)
- [x] Run `flutter analyze` (no new warnings — only 3 pre-existing deprecation infos)
- [x] Run `flutter test` (all 57 tests pass)
