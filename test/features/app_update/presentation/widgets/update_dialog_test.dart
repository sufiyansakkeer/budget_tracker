import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/app_update/domain/entities/app_update_result.dart';
import 'package:monivo/features/app_update/domain/entities/update_status.dart';
import 'package:monivo/features/app_update/presentation/widgets/update_dialog_service.dart';

void main() {
  late AppUpdateResult testResult;

  setUp(() {
    UpdateDialogService.resetGuard();
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

    expect(find.text('Update Available'), findsOneWidget);
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

    expect(find.text('Update Available'), findsNothing);
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
    expect(find.text('Update Available'), findsOneWidget);
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
    expect(find.text('Update Available'), findsOneWidget);
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

    expect(find.text('Update Available'), findsOneWidget);
  });
}
