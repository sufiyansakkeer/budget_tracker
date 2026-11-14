import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/features/app_update/domain/entities/app_update_result.dart';
import 'package:monivo/features/app_update/domain/entities/update_status.dart';
import 'package:monivo/features/app_update/presentation/widgets/update_dialog_service.dart';
import 'package:monivo/features/app_update/presentation/widgets/update_prompt_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppUpdateResult testResult;

  setUp(() {
    UpdateDialogService.resetGuard();
    SharedPreferences.setMockInitialValues({});
    testResult = const AppUpdateResult(
      status: UpdateStatus.updateAvailable,
      currentVersion: '1.0.0',
      latestVersion: '1.1.0',
      releaseUrl: 'https://github.com/test/repo/releases/tag/v1.1.0',
      releaseTitle: 'Release 1.1.0',
      releaseNotes: '- Fixed bug A\n- Added feature B',
    );
  });

  /// Build a test app using the service's own root navigator key so that
  /// [UpdateDialogService.show] can locate the Navigator.
  Widget buildTestableApp() {
    return MaterialApp(
      navigatorKey: UpdateDialogService.rootNavigatorKey,
      home: const Scaffold(),
    );
  }

  testWidgets('shows update dialog with correct title', (tester) async {
    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('displays current and latest version', (tester) async {
    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('v1.1.0'), findsWidgets);
  });

  testWidgets('displays release notes', (tester) async {
    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    expect(find.text("What's new?"), findsOneWidget);
    expect(find.textContaining('Fixed bug A'), findsOneWidget);
  });

  testWidgets('has Update and Later buttons', (tester) async {
    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('Later button dismisses dialog', (tester) async {
    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('dialog is not dismissible by tapping outside', (tester) async {
    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    // Try to tap outside the dialog
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Dialog should still be visible (barrierDismissible: false)
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('hides release notes section when notes are empty', (
    tester,
  ) async {
    final noNotesResult = const AppUpdateResult(
      status: UpdateStatus.updateAvailable,
      currentVersion: '1.0.0',
      latestVersion: '1.1.0',
      releaseUrl: 'https://example.com',
      releaseTitle: 'Release',
      releaseNotes: '',
    );

    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    UpdateDialogService.show(noNotesResult);
    await tester.pumpAndSettle();

    expect(find.text("What's new?"), findsNothing);
  });

  testWidgets('prevents duplicate dialogs', (tester) async {
    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    // Show again — should be blocked by the guard
    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    // Should still have exactly one dialog
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('guard resets after dialog is dismissed', (tester) async {
    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    // Guard should be cleared — show again
    UpdateDialogService.show(testResult);
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
  });

  group('on launch', () {
    var now = DateTime(2026, 10, 10, 9);

    setUp(() {
      now = DateTime(2026, 10, 10, 9);
      UpdatePromptPolicy.clock = () => now;
    });

    tearDown(() => UpdatePromptPolicy.clock = DateTime.now);

    Future<bool> notFromWidget() async => false;

    /// Shows the launch dialog, as main does, and says whether it appeared.
    Future<bool> launch(
      WidgetTester tester, {
      AppUpdateResult? result,
      Future<bool> Function()? openedFromWidget,
    }) async {
      UpdateDialogService.resetGuard();
      await UpdateDialogService.showOnLaunch(
        result ?? testResult,
        openedFromWidget: openedFromWidget ?? notFromWidget,
      );
      await tester.pumpAndSettle();
      return find.text('Update available').evaluate().isNotEmpty;
    }

    testWidgets('"Later" keeps it away for a day', (tester) async {
      await tester.pumpWidget(buildTestableApp());
      expect(await launch(tester), isTrue);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      // The next cold starts that day.
      now = now.add(const Duration(hours: 23));
      expect(await launch(tester), isFalse);

      now = now.add(const Duration(hours: 1));
      expect(await launch(tester), isTrue);
    });

    testWidgets('"Skip this version" keeps it away until a newer release', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableApp());
      expect(await launch(tester), isTrue);
      await tester.tap(find.text('Skip this version'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      now = now.add(const Duration(days: 30));
      expect(await launch(tester), isFalse);

      const newer = AppUpdateResult(
        status: UpdateStatus.updateAvailable,
        currentVersion: '1.0.0',
        latestVersion: '1.2.0',
        releaseUrl: 'https://github.com/test/repo/releases/tag/v1.2.0',
      );
      expect(await launch(tester, result: newer), isTrue);
    });

    testWidgets('never over a widget or notification link', (tester) async {
      await tester.pumpWidget(buildTestableApp());
      expect(await launch(tester, openedFromWidget: () async => true), isFalse);
    });

    testWidgets('only on Home: never during onboarding or on a linked screen', (
      tester,
    ) async {
      final router = GoRouter(
        navigatorKey: UpdateDialogService.rootNavigatorKey,
        initialLocation: '/onboarding',
        routes: [
          for (final path in ['/onboarding', '/app/home', '/app/expenses/add'])
            GoRoute(
              path: path,
              builder: (context, state) => Scaffold(body: Text(path)),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(await launch(tester), isFalse);

      router.go('/app/expenses/add');
      await tester.pumpAndSettle();
      expect(await launch(tester), isFalse);

      router.go('/app/home');
      await tester.pumpAndSettle();
      expect(await launch(tester), isTrue);
    });

    testWidgets('the dialog scrolls at large text in landscape', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: UpdateDialogService.rootNavigatorKey,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(),
        ),
      );
      UpdateDialogService.show(testResult);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Skip this version'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Skip this version').hitTestable(), findsOneWidget);
    });
  });
}
