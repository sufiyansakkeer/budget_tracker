import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:monivo/features/settings/presentation/widgets/theme_selector.dart';

void main() {
  group('ThemeSelector', () {
    testWidgets('should display all theme options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeSelector(
              selectedMode: AppThemeMode.system,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('should highlight selected theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeSelector(
              selectedMode: AppThemeMode.dark,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Find the dark theme option and verify it's selected
      final darkOption = find.ancestor(
        of: find.text('Dark'),
        matching: find.byType(InkWell),
      );

      expect(darkOption, findsOneWidget);
    });

    testWidgets('should call onChanged when theme is selected', (tester) async {
      AppThemeMode? selectedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeSelector(
              selectedMode: AppThemeMode.system,
              onChanged: (mode) => selectedMode = mode,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Light'));
      await tester.pump();

      expect(selectedMode, AppThemeMode.light);
    });

    testWidgets('should display theme descriptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeSelector(
              selectedMode: AppThemeMode.system,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Follow device theme'), findsOneWidget);
      expect(find.text('Always use light theme'), findsOneWidget);
      expect(find.text('Always use dark theme'), findsOneWidget);
    });

    testWidgets('should display theme icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeSelector(
              selectedMode: AppThemeMode.system,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });
  });
}
