import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/currency/currency_provider.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/core/files/file_delivery_service.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/notifications/notification_permission_notice.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';
import 'package:monivo/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_event.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_state.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_event.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_state.dart';
import 'package:monivo/features/settings/presentation/pages/settings_screen.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../budget/presentation/pages/budget_form_screen_test.dart'
    show FakeSettingsRepository;
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
    Brightness brightness = Brightness.light,
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
        theme: brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme,
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

  group('More tiles (blueprint)', () {
    testWidgets('every feature beyond the daily view leads the screen', (
      tester,
    ) async {
      await pump(tester);

      final tiles = find.byKey(const Key('moreTiles'));
      expect(tiles, findsOneWidget);
      for (final title in const [
        'Bills',
        'Pay later',
        'Categories',
        'Currency converter',
        'All budgets',
        'Your data',
      ]) {
        expect(
          find.descendant(of: tiles, matching: find.text(title)),
          findsOneWidget,
          reason: title,
        );
      }
      // The rows the tiles replace are gone.
      expect(find.text('Budgets'), findsNothing);
    });

    testWidgets('"Your data" brings the data settings into view', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Your data'));
      await tester.pumpAndSettle();

      expect(find.text('Data').hitTestable(), findsOneWidget);
    });
  });

  group('notifications', () {
    testWidgets('UX-013: blocked notifications are said under the switch', (
      tester,
    ) async {
      getIt.registerSingleton<NotificationPermission>(
        NotificationPermission(
          isAllowed: () async => false,
          request: () async => false,
        ),
      );
      await pump(tester);

      expect(find.text('Notifications are blocked for Monivo'), findsOneWidget);
      final toggle = tester.getRect(find.text('Daily notifications'));
      final notice = tester.getRect(
        find.text('Notifications are blocked for Monivo'),
      );
      expect(notice.top, greaterThan(toggle.bottom));
      expect(
        notice.top,
        lessThan(tester.getRect(find.text('Morning target')).top),
      );
    });

    testWidgets('times use the same format as the rest of Settings', (
      tester,
    ) async {
      await pump(tester);

      final morning = time(tester, 8, 0);
      final evening = time(tester, 21, 30);
      // On the row (the summary strip gave way to the More tiles).
      expect(find.textContaining(morning), findsOneWidget);
      expect(find.textContaining(evening), findsOneWidget);
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
          of: find.text('Morning target'),
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

    testWidgets('UX-002: Back up asks where the file goes before making it', (
      tester,
    ) async {
      final (settings, _) = await pump(tester);

      await tester.ensureVisible(find.text('Back up'));
      await tester.tap(find.text('Back up'));
      await tester.pumpAndSettle();

      expect(find.text('Save to this device'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.textContaining('Restore can open it'), findsOneWidget);
      expect(
        settings.received.whereType<SettingsBackupEvent>(),
        isEmpty,
        reason: 'nothing is made until a destination is chosen',
      );

      await tester.tap(find.text('Save to this device'));
      await tester.pumpAndSettle();
      expect(
        settings.received,
        contains(const SettingsBackupEvent(FileDestination.device)),
      );
    });

    testWidgets('UX-019: export and shared backups anchor the share sheet '
        'to their row (iPad)', (tester) async {
      final (settings, _) = await pump(tester);
      final exportRow = tester.getRect(
        find.byKey(const Key('settingsExportTile')),
      );
      final backupRow = tester.getRect(
        find.byKey(const Key('settingsBackupTile')),
      );

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spreadsheet (CSV)'));
      await tester.pumpAndSettle();
      expect(
        settings.received.whereType<SettingsExportEvent>().single.shareOrigin,
        exportRow,
      );

      await tester.tap(find.text('Back up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(
        settings.received.whereType<SettingsBackupEvent>().single.shareOrigin,
        backupRow,
      );
    });

    testWidgets('UX-003: the JSON export says it is not a backup', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Not a backup'), findsOneWidget);
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

  testWidgets('tiles other flows rely on keep their keys', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('more_categories')), findsOneWidget);
    expect(find.byKey(const Key('more_converter')), findsOneWidget);
    expect(find.byKey(const Key('more_payLater')), findsOneWidget);
  });

  testWidgets('about shows the installed version', (tester) async {
    await pump(tester);

    expect(find.text('v1.0.0 (1)'), findsOneWidget);
    expect(find.text('Open source licenses'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('meets tap target, label and contrast guidelines '
        '(${brightness.name})', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, brightness: brightness, withIntegrityCheck: true);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  testWidgets('fits a small screen at twice the text size', (tester) async {
    await pump(tester, width: 320, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Restore from backup'), findsOneWidget);
  });

  group('UX-099: the default currency', () {
    testWidgets('reaches the app only once saved; row and picker agree', (
      tester,
    ) async {
      final provider = CurrencyProvider(
        loadSettingsUseCase: LoadSettingsUseCase(
          repository: FakeSettingsRepository(),
        ),
      );
      getIt.registerSingleton<CurrencyProvider>(provider);
      final (settings, _) = await pump(tester);
      // After its own first read, the app's currency matches Settings.
      provider.updateCurrency('USD', r'$');

      const scope = 'Default for new budgets and Pay later tabs';
      expect(find.text(scope), findsOneWidget, reason: 'the row');
      // The summary strip says "Currency" too: tap the row.
      await tester.tap(find.text(scope));
      await tester.pumpAndSettle();
      expect(find.text(scope), findsNWidgets(2), reason: 'and the picker');

      await tester.tap(find.text('OMR').last);
      await tester.pumpAndSettle();
      expect(
        settings.received.whereType<SettingsUpdateCurrencyEvent>().single.code,
        'OMR',
      );
      expect(provider.currencyCode, 'USD', reason: 'not saved yet');

      // The save succeeded.
      settings.emit(
        loadedSettings.copyWith(
          settings: loadedSettings.settings.copyWith(
            currencyCode: 'OMR',
            currencySymbol: 'ر.ع.',
          ),
        ),
      );
      await tester.pump();
      expect(provider.currencyCode, 'OMR');
    });

    testWidgets('a currency save leaves the Data rows usable', (tester) async {
      await pump(tester);
      for (final title in ['Export', 'Import', 'Back up']) {
        final tile = tester.widget<ListTile>(
          find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
        );
        expect(tile.enabled, isTrue, reason: title);
      }
    });
  });

  group('UX-095: start a new period', () {
    Future<(GoRouter, StaticSettingsBloc)> pumpRouted(
      WidgetTester tester, {
      required String? activeId,
    }) async {
      getIt.registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(
          repository: ListBudgetRepository([
            if (activeId != null)
              BudgetEntity(
                id: activeId,
                name: 'October',
                monthlyAmount: 30000,
                remainingAmount: 30000,
                currency: 'INR',
                startDate: DateTime(2026, 10, 1),
                endDate: DateTime(2026, 10, 31),
                createdAt: DateTime(2026, 10, 1),
                updatedAt: DateTime(2026, 10, 1),
              ),
          ], activeId),
          reconcileTabs: FakeReconcileTabUseCase(),
        ),
      );
      final settings = StaticSettingsBloc(loadedSettings);
      final themeBloc = StaticThemeBloc(const ThemeState());
      addTearDown(settings.close);
      addTearDown(themeBloc.close);
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(720, 18000);
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                settingsScreen(settings: settings, theme: themeBloc),
          ),
          GoRoute(
            path: '/app/budgets',
            builder: (context, state) => const Text('Budget list'),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const Text('New budget form'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();
      return (router, settings);
    }

    testWidgets('with no budget, opens Create budget instead of a 0 budget', (
      tester,
    ) async {
      final (_, settings) = await pumpRouted(tester, activeId: null);

      await tester.tap(find.text('Start new budget period'));
      await tester.pumpAndSettle();

      expect(find.text('Start a new budget period?'), findsNothing);
      expect(find.text('New budget form'), findsOneWidget);
      expect(
        settings.received,
        isNot(contains(const SettingsResetMonthEvent())),
      );
    });

    testWidgets('with a budget, still asks first', (tester) async {
      final (_, settings) = await pumpRouted(tester, activeId: 'oct');

      await tester.tap(find.text('Start new budget period'));
      await tester.pumpAndSettle();
      expect(find.text('Start a new budget period?'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(settings.received, contains(const SettingsResetMonthEvent()));
    });
  });
}
