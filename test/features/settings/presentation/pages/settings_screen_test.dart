import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';
import 'package:monivo/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_event.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_state.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_event.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_state.dart';
import 'package:monivo/features/settings/presentation/pages/settings_screen.dart';

import 'settings_test_harness.dart';

void main() {
  setUp(setUpSettingsScreen);
  tearDown(() => getIt.reset());

  Future<(StaticSettingsBloc, StaticThemeBloc)> pump(
    WidgetTester tester, {
    SettingsState state = loadedSettings,
    ThemeState theme = const ThemeState(),
    bool withIntegrityCheck = false,
    double width = 360,
    double textScale = 1,
    bool settle = true,
  }) async {
    final settings = StaticSettingsBloc(
      state,
      integrityService: withIntegrityCheck ? FakeIntegrityService() : null,
    );
    final themeBloc = StaticThemeBloc(theme);
    addTearDown(settings.close);
    addTearDown(themeBloc.close);
    // Tall enough that every group is built.
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(width * 2, 9000 * textScale);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: settingsScreen(settings: settings, theme: themeBloc),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
    return (settings, themeBloc);
  }

  String time(WidgetTester tester, int hour, int minute) => TimeOfDay(
    hour: hour,
    minute: minute,
  ).format(tester.element(find.byType(SettingsScreen)));

  Finder inSummary(String text) => find.descendant(
    of: find.byKey(const Key('settingsSummary')),
    matching: find.text(text),
  );

  group('summary strip', () {
    testWidgets('shows the current choices', (tester) async {
      await pump(
        tester,
        state: loadedSettings.copyWith(
          settings: loadedSettings.settings.copyWith(biometricEnabled: true),
        ),
        theme: const ThemeState(
          mode: AppThemeMode.dark,
          palette: ColorPalette.ocean,
        ),
      );

      expect(inSummary('USD'), findsOneWidget);
      expect(inSummary('Dark · Ocean'), findsOneWidget);
      expect(
        inSummary('${time(tester, 8, 0)} · ${time(tester, 21, 30)}'),
        findsOneWidget,
      );
      expect(inSummary('On'), findsOneWidget);
    });

    testWidgets('reminders read Off when notifications are off', (
      tester,
    ) async {
      await pump(
        tester,
        state: loadedSettings.copyWith(
          settings: loadedSettings.settings.copyWith(
            notifications: const NotificationSettings(
              notificationsEnabled: false,
            ),
          ),
        ),
      );

      expect(inSummary('Off'), findsNWidgets(2), reason: 'reminders, lock');
    });
  });

  group('notifications', () {
    testWidgets('times use the same format as the rest of Settings', (
      tester,
    ) async {
      await pump(tester);

      final morning = time(tester, 8, 0);
      final evening = time(tester, 21, 30);
      // Once in the summary, once on the row.
      expect(find.textContaining(morning), findsNWidgets(2));
      expect(find.textContaining(evening), findsNWidgets(2));
      // The 24-hour pills are gone.
      expect(find.text('08:00'), findsNothing);
      expect(find.text('21:30'), findsNothing);
    });

    testWidgets('time rows are disabled while notifications are off', (
      tester,
    ) async {
      await pump(
        tester,
        state: loadedSettings.copyWith(
          settings: loadedSettings.settings.copyWith(
            notifications: const NotificationSettings(
              notificationsEnabled: false,
            ),
          ),
        ),
      );

      final morning = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Morning reminder'),
          matching: find.byType(ListTile),
        ),
      );
      expect(morning.enabled, isFalse);
      expect(morning.onTap, isNull);
    });
  });

  group('appearance', () {
    testWidgets('the theme control marks the choice and dispatches a new one', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final (_, theme) = await pump(
        tester,
        theme: const ThemeState(mode: AppThemeMode.light),
      );

      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Light, Always use light theme'),
        ),
        containsSemantics(isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Dark, Always use dark theme'),
        ),
        containsSemantics(isSelected: false, isButton: true),
      );

      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(
        theme.received,
        contains(
          isA<ThemeChanged>().having((e) => e.mode, 'mode', AppThemeMode.dark),
        ),
      );
      semantics.dispose();
    });

    testWidgets('the palette row shows the current palette', (tester) async {
      await pump(tester, theme: const ThemeState(palette: ColorPalette.forest));

      final row = find.ancestor(
        of: find.text('Color palette'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: row, matching: find.text('Forest')),
        findsOneWidget,
      );
    });
  });

  group('data', () {
    testWidgets('export opens a sheet that explains each format', (
      tester,
    ) async {
      final (settings, _) = await pump(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.text('Spreadsheet (CSV)'), findsOneWidget);
      expect(find.text('Data file (JSON)'), findsOneWidget);
      expect(find.textContaining('Opens in Excel'), findsOneWidget);
      expect(
        find.textContaining('Budgets, categories, expenses and settings'),
        findsOneWidget,
      );

      await tester.tap(find.text('Spreadsheet (CSV)'));
      await tester.pumpAndSettle();
      expect(settings.received, contains(const SettingsExportEvent(csv: true)));
      expect(find.text('Spreadsheet (CSV)'), findsNothing, reason: 'closed');
    });

    testWidgets('the JSON export is its own choice', (tester) async {
      final (settings, _) = await pump(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Data file (JSON)'));
      await tester.pumpAndSettle();

      expect(
        settings.received,
        contains(const SettingsExportEvent(csv: false)),
      );
    });

    testWidgets('import explains that files are merged', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Records from the file are merged into what you already have.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('header row'), findsOneWidget);
    });

    testWidgets('restore is styled as destructive, export is not', (
      tester,
    ) async {
      await pump(tester);
      final error = AppTheme.lightTheme.colorScheme.error;

      expect(
        tester.widget<Text>(find.text('Restore from backup')).style?.color,
        error,
      );
      expect(
        tester.widget<Text>(find.text('Export')).style?.color,
        isNot(error),
      );
    });

    testWidgets('while busy the rows are disabled and a progress line shows', (
      tester,
    ) async {
      await pump(
        tester,
        state: loadedSettings.copyWith(isBusy: true),
        settle: false,
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      for (final title in [
        'Export',
        'Import',
        'Back up',
        'Restore from backup',
      ]) {
        final tile = tester.widget<ListTile>(
          find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
        );
        expect(tile.enabled, isFalse, reason: title);
      }
    });

    testWidgets('the database check is hidden without its service', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('checkIntegrityButton')), findsNothing);
    });

    testWidgets('the database check runs from its row', (tester) async {
      final (settings, _) = await pump(tester, withIntegrityCheck: true);

      await tester.tap(find.byKey(const Key('checkIntegrityButton')));
      await tester.pump();
      expect(settings.received, contains(const SettingsCheckIntegrityEvent()));
    });
  });

  testWidgets('rows other flows rely on keep their keys', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('settingsCategoriesTile')), findsOneWidget);
    expect(
      find.byKey(const Key('settingsCurrencyConverterTile')),
      findsOneWidget,
    );
  });

  testWidgets('about shows the installed version', (tester) async {
    await pump(tester);

    expect(find.text('v1.0.0 (1)'), findsOneWidget);
    expect(find.text('Open source licenses'), findsOneWidget);
  });

  testWidgets('fits a small screen at twice the text size', (tester) async {
    await pump(tester, width: 320, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Restore from backup'), findsOneWidget);
  });
}
