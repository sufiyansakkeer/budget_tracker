import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/notifications/notification_permission_notice.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/dashboard/presentation/widgets/notification_priming_card.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UX-013: with no permission prompt at launch, a fresh install was never
/// asked, so the default-on morning reminder never arrived.
class _Permission {
  bool allowed;
  int requests = 0;

  _Permission({this.allowed = false});

  NotificationPermission get api => NotificationPermission(
    isAllowed: () async => allowed,
    request: () async {
      requests++;
      return allowed;
    },
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    _Permission permission, {
    NotificationSettings settings = const NotificationSettings(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: NotificationPrimingCard(
            permission: permission.api,
            loadSettings: () async => settings,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers the morning reminder while notifications are blocked', (
    tester,
  ) async {
    await pump(tester, _Permission());

    expect(find.text("Get Today's Safe Spending each morning"), findsOneWidget);
    expect(find.textContaining('9:00'), findsOneWidget);
    expect(find.text('Allow notifications'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('says nothing when notifications are already allowed', (
    tester,
  ) async {
    await pump(tester, _Permission(allowed: true));
    expect(find.text('Allow notifications'), findsNothing);
  });

  testWidgets('says nothing when reminders are turned off', (tester) async {
    await pump(
      tester,
      _Permission(),
      settings: const NotificationSettings(notificationsEnabled: false),
    );
    expect(find.text('Allow notifications'), findsNothing);
  });

  testWidgets('"Allow notifications" asks the system once, then goes', (
    tester,
  ) async {
    final permission = _Permission();
    await pump(tester, permission);

    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();

    expect(permission.requests, 1);
    expect(find.text('Allow notifications'), findsNothing);
  });

  testWidgets('"Not now" hides it for good', (tester) async {
    final permission = _Permission();
    await pump(tester, permission);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Not now'), findsNothing);
    expect(permission.requests, 0);

    // A later visit to Home doesn't offer it again.
    await tester.pumpWidget(const SizedBox());
    await pump(tester, permission);
    expect(find.text('Not now'), findsNothing);
  });

  testWidgets('without the app\'s permission service it never shows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: NotificationPrimingCard()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Allow notifications'), findsNothing);
  });
}
