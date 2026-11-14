import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/settings/presentation/widgets/about_section.dart';

/// The Privacy text called "Check for updates" optional, while the app asks
/// GitHub for the latest version on every launch.
void main() {
  testWidgets('Privacy says the update check runs when the app opens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SingleChildScrollView(child: AboutSection()),
        ),
      ),
    );
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('optional'), findsNothing);
    expect(
      find.textContaining(
        'each time it opens, and when you tap "Check for updates"',
      ),
      findsOneWidget,
    );
  });
}
