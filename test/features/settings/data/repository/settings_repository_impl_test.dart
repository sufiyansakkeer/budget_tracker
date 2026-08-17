import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/settings/data/datasource/settings_local_datasource_impl.dart';
import 'package:monivo/features/settings/data/repository/settings_repository_impl.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase database;
  late SharedPreferences prefs;
  late SettingsRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    database = await createInMemoryDatabase();
    repository = SettingsRepositoryImpl(
      localDataSource: SettingsLocalDataSourceImpl(
        database: database,
        sharedPreferences: prefs,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('SettingsRepositoryImpl - Biometric persistence', () {
    test('biometric defaults to disabled', () async {
      final settings = await repository.loadSettings();
      expect(settings.biometricEnabled, false);
    });

    test('save true then load returns enabled', () async {
      await repository.setBiometricEnabled(true);

      final settings = await repository.loadSettings();
      expect(settings.biometricEnabled, true);
    });

    test('save false keeps it disabled', () async {
      // Start enabled.
      await repository.setBiometricEnabled(true);
      var settings = await repository.loadSettings();
      expect(settings.biometricEnabled, true);

      // Disable.
      await repository.setBiometricEnabled(false);
      settings = await repository.loadSettings();
      expect(settings.biometricEnabled, false);
    });

    test(
      'persists across repository instances (app restart simulation)',
      () async {
        // Save via one instance.
        await repository.setBiometricEnabled(true);

        // Create a fresh repository pointing at the same underlying storage.
        final freshRepository = SettingsRepositoryImpl(
          localDataSource: SettingsLocalDataSourceImpl(
            database: database,
            sharedPreferences: prefs,
          ),
        );

        final settings = await freshRepository.loadSettings();
        expect(settings.biometricEnabled, true);
      },
    );

    test('does not mutate other settings', () async {
      await repository.setBiometricEnabled(true);

      final settings = await repository.loadSettings();
      expect(settings.biometricEnabled, true);
      expect(settings.currencyCode, 'INR');
      expect(settings.notifications.notificationsEnabled, true);
      expect(settings.themeMode, AppSettings().themeMode);
    });
  });
}
