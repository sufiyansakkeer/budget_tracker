import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/features/settings/presentation/widgets/settings_tile.dart';

void main() {
  group('SettingsTile', () {
    testWidgets('should display title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              icon: Icons.settings,
              title: 'Test Title',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('should display icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              icon: Icons.settings,
              title: 'Test Title',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should display subtitle when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              icon: Icons.settings,
              title: 'Test Title',
              subtitle: 'Test Subtitle',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Subtitle'), findsOneWidget);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              icon: Icons.settings,
              title: 'Test Title',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('should display trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              icon: Icons.settings,
              title: 'Test Title',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('should not be tappable when onTap is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SettingsTile(icon: Icons.settings, title: 'Test Title'),
          ),
        ),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.onTap, isNull);
    });
  });
}
