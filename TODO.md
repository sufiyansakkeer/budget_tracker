# Phase 7 – Reports & Analytics Module TODO

## Domain – Entities
- [x] Create `domain/entities/report_period.dart`
- [x] Create `domain/entities/report_overview.dart`
- [x] Create `domain/entities/daily_spending_point.dart`
- [x] Create `domain/entities/monthly_spending_bucket.dart`
- [x] Create `domain/entities/category_slice.dart`
- [x] Create `domain/entities/category_analytics.dart`
- [x] Create `domain/entities/time_analytics.dart`
- [x] Create `domain/entities/spending_trend.dart`
- [x] Create `domain/entities/weekly_comparison.dart`
- [x] Create `domain/entities/report_data.dart`
- [x] Create `domain/entities/report_failure.dart`

## Domain – Services
- [x] Create `domain/services/analytics_service.dart`
- [x] Create `domain/services/report_insight_generator.dart`

## Domain – Repository
- [x] Create `domain/repository/reports_repository.dart`
- [x] Create `data/repository/reports_repository_impl.dart`

## Domain – Use Cases
- [x] Create `domain/usecases/get_report_data_usecase.dart`
- [x] Create `domain/usecases/export_csv_usecase.dart`
- [x] Create `domain/usecases/export_pdf_usecase.dart`

## Presentation – BLoC
- [x] Create `presentation/bloc/reports_event.dart`
- [x] Create `presentation/bloc/reports_state.dart`
- [x] Create `presentation/bloc/reports_bloc.dart`

## Presentation – Widgets
- [x] Create `presentation/widgets/report_overview_card.dart`
- [x] Create `presentation/widgets/period_selector.dart`
- [x] Create `presentation/widgets/analytics_section.dart`
- [x] Create `presentation/widgets/line_chart_card.dart`
- [x] Create `presentation/widgets/bar_chart_card.dart`
- [x] Create `presentation/widgets/pie_chart_card.dart`
- [x] Create `presentation/widgets/budget_utilization_card.dart`
- [x] Create `presentation/widgets/category_analytics_card.dart`
- [x] Create `presentation/widgets/weekly_comparison_card.dart`
- [x] Create `presentation/widgets/time_analytics_card.dart`
- [x] Create `presentation/widgets/trend_card.dart`
- [x] Create `presentation/widgets/insight_card.dart`
- [x] Create `presentation/widgets/export_buttons.dart`
- [x] Create `presentation/widgets/empty_reports_state.dart`
- [x] Create `presentation/widgets/reports_error_widget.dart`

## Presentation – Pages
- [x] Create `presentation/pages/reports_screen.dart`

## Integration
- [x] Update `core/router/app_router.dart` – wire `/reports` to ReportsScreen
- [x] Update `core/di/injection.dart` – register reports use cases + bloc

## Tests
- [x] Unit tests: analytics service, category calcs, trend calcs, time analytics, weekly comparison
- [x] Unit tests: insight generator
- [x] Unit tests: report range
- [x] Unit tests: export logic (CSV/PDF)
- [x] Widget tests: reports screen (loaded/empty/error)
- [x] Widget tests: period selector, category analytics, charts

## Verification
- [x] `flutter analyze` passes (only pre-existing info-level lints)
- [x] `flutter test` passes (190 tests)
- [x] `flutter build apk --debug` succeeds
- [x] Summary of completed functionality
