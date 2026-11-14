import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/notifications/notification_permission_notice.dart';
import 'package:monivo/core/theme/app_theme.dart';

/// UX-013: reminders read "on" while the system blocked Monivo's
/// notifications, so they silently never arrived.
class _Permission {
  bool allowed;

  /// What the system prompt answers.
  bool grantOnRequest;
  int requests = 0;

  _Permission({this.allowed = false, this.grantOnRequest = false});

  NotificationPermission get api => NotificationPermission(
    isAllowed: () async => allowed,
    request: () async {
      requests++;
      allowed = allowed || grantOnRequest;
      return allowed;
    },
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _Permission permission, {
    required bool remindersOn,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: NotificationPermissionNotice(
            remindersOn: remindersOn,
            permission: permission.api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const title = 'Notifications are blocked for Monivo';

  testWidgets('says so when reminders are on and notifications blocked', (
    tester,
  ) async {
    final permission = _Permission();
    await pump(tester, permission, remindersOn: true);

    expect(find.text(title), findsOneWidget);
    expect(find.text('Allow notifications'), findsOneWidget);
    expect(permission.requests, 0, reason: 'never asks on its own at load');
  });

  testWidgets('says nothing when allowed, or when reminders are off', (
    tester,
  ) async {
    await pump(tester, _Permission(allowed: true), remindersOn: true);
    expect(find.text(title), findsNothing);

    await pump(tester, _Permission(), remindersOn: false);
    expect(find.text(title), findsNothing);
  });

  testWidgets('turning reminders on asks for permission', (tester) async {
    final permission = _Permission(grantOnRequest: true);
    await pump(tester, permission, remindersOn: false);

    await pump(tester, permission, remindersOn: true);

    expect(permission.requests, 1);
    expect(find.text(title), findsNothing);
  });

  testWidgets('a refused request says where to allow them instead', (
    tester,
  ) async {
    final permission = _Permission();
    await pump(tester, permission, remindersOn: true);

    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();

    expect(permission.requests, 1);
    expect(find.text(title), findsOneWidget);
    expect(find.text('Allow notifications'), findsNothing);
    expect(find.textContaining("your phone's Settings"), findsOneWidget);
  });

  testWidgets('allowed in system settings: gone on return to the app', (
    tester,
  ) async {
    final permission = _Permission();
    await pump(tester, permission, remindersOn: true);
    expect(find.text(title), findsOneWidget);

    permission.allowed = true;
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();

    expect(find.text(title), findsNothing);
  });
}
