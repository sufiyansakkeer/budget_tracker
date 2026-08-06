# Phase 8 – Settings, Notifications, Security & Data Management TODO

## Domain – Entities
- [ ] Create `domain/entities/app_settings.dart`
- [ ] Create `domain/entities/theme_mode_entity.dart`
- [ ] Create `domain/entities/notification_settings.dart`
- [ ] Create `domain/entities/settings_failure.dart`

## Domain – Repository
- [ ] Create `domain/repository/settings_repository.dart`
- [ ] Create `data/datasource/settings_local_datasource.dart`
- [ ] Create `data/datasource/settings_local_datasource_impl.dart`
- [ ] Create `data/repository/settings_repository_impl.dart`

## Domain – Services
- [ ] Create `domain/services/notification_service.dart`
- [ ] Create `domain/services/biometric_service.dart`
- [ ] Create `domain/services/backup_service.dart`
- [ ] Create `domain/services/export_service.dart`
- [ ] Create `domain/services/import_service.dart`

## Domain – Use Cases
- [ ] Create `domain/usecases/load_settings_usecase.dart`
- [ ] Create `domain/usecases/update_theme_usecase.dart`
- [ ] Create `domain/usecases/update_currency_usecase.dart`
- [ ] Create `domain/usecases/update_notification_settings_usecase.dart`
- [ ] Create `domain/usecases/update_biometric_usecase.dart`
- [ ] Create `domain/usecases/export_data_usecase.dart`
- [ ] Create `domain/usecases/import_data_usecase.dart`
- [ ] Create `domain/usecases/backup_data_usecase.dart`
- [ ] Create `domain/usecases/restore_data_usecase.dart`
- [ ] Create `domain/usecases/reset_budget_usecase.dart`

## Presentation – BLoC
- [ ] Create `presentation/bloc/settings_event.dart`
- [ ] Create `presentation/bloc/settings_state.dart`
- [ ] Create `presentation/bloc/settings_bloc.dart`

## Presentation – Widgets
- [ ] Create `presentation/widgets/settings_section.dart`
- [ ] Create `presentation/widgets/settings_tile.dart`
- [ ] Create `presentation/widgets/theme_selector.dart`
- [ ] Create `presentation/widgets/currency_selector.dart`
- [ ] Create `presentation/widgets/notification_time_tile.dart`
- [ ] Create `presentation/widgets/notification_toggle.dart`
- [ ] Create `presentation/widgets/biometric_tile.dart`
- [ ] Create `presentation/widgets/data_management_card.dart`
- [ ] Create `presentation/widgets/reset_confirmation_dialog.dart`
- [ ] Create `presentation/widgets/about_card.dart`

## Presentation – Pages
- [ ] Create `presentation/pages/settings_screen.dart`

## Integration
- [ ] Update `core/router/app_router.dart` – wire `/settings` to SettingsScreen
- [ ] Update `core/di/injection.dart` – register settings datasource, repository, services, use cases + bloc
- [ ] Update `main.dart` – dynamic theme via SettingsBloc
- [ ] Update `android/app/src/main/AndroidManifest.xml` – biometric + notification permissions
- [ ] Update `ios/Runner/Info.plist` – Face ID usage description

## Tests
- [ ] Unit tests: settings repository
- [ ] Unit tests: notification service
- [ ] Unit tests: backup service
- [ ] Unit tests: import/export service
- [ ] Unit tests: biometric service
- [ ] Widget tests: settings screen
- [ ] Widget tests: theme selector, currency selector, notification settings

## Verification
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] `flutter build apk --debug` succeeds
- [ ] Summary of completed functionality


