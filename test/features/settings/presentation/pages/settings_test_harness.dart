import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/services/database_integrity_service.dart';
import 'package:monivo/features/app_update/presentation/bloc/app_update_bloc.dart';
import 'package:monivo/features/app_update/presentation/bloc/app_update_event.dart';
import 'package:monivo/features/app_update/presentation/bloc/app_update_state.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_event.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_state.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_event.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_state.dart';
import 'package:monivo/features/settings/presentation/pages/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A SettingsBloc that only holds a given state; events are recorded.
class StaticSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  final List<SettingsEvent> received = [];

  @override
  final DatabaseIntegrityService? integrityService;

  StaticSettingsBloc(super.initialState, {this.integrityService}) {
    on<SettingsEvent>((event, _) => received.add(event));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A ThemeBloc that only holds a given state; events are recorded.
class StaticThemeBloc extends Bloc<ThemeEvent, ThemeState>
    implements ThemeBloc {
  final List<ThemeEvent> received = [];

  StaticThemeBloc(super.initialState) {
    on<ThemeEvent>((event, _) => received.add(event));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The update section's bloc, idle until asked.
class StaticAppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {
  StaticAppUpdateBloc() : super(const AppUpdateInitial()) {
    on<AppUpdateEvent>((_, _) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Present only so Settings shows the database check row.
class FakeIntegrityService implements DatabaseIntegrityService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Loaded settings: dollars, both reminders on at 8:00 and 21:30, no lock.
const loadedSettings = SettingsState(
  status: SettingsStatus.loaded,
  settings: AppSettings(
    currencyCode: 'USD',
    currencySymbol: r'$',
    notifications: NotificationSettings(
      morningReminderTime: NotificationTime(hour: 8, minute: 0),
      eveningSummaryTime: NotificationTime(hour: 21, minute: 30),
    ),
  ),
);

/// Registers what Settings reads outside its blocs: the update bloc from
/// GetIt and the version from the platform. Call in `setUp`.
Future<void> setUpSettingsScreen() async {
  await getIt.reset();
  getIt.registerSingleton<AppUpdateBloc>(StaticAppUpdateBloc());
  PackageInfo.setMockInitialValues(
    appName: 'Monivo',
    packageName: 'com.example.monivo',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
}

/// The Settings screen over the two blocs it reads.
Widget settingsScreen({
  required StaticSettingsBloc settings,
  required StaticThemeBloc theme,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsBloc>.value(value: settings),
      BlocProvider<ThemeBloc>.value(value: theme),
    ],
    child: const SettingsScreen(),
  );
}
