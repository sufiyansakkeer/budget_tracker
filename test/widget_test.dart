import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/core/di/injection.dart';
import 'package:budget_tracker/main.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'isFirstLaunch': false});
    if (!getIt.isRegistered<SharedPreferences>()) {
      await initDependencyInjection();
    }
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Wrap in a MaterialApp so the BiometricGateScreen's Scaffold has a
    // Directionality ancestor in the test environment.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SmartBudgetApp())),
    );
    // Dashboard screens may contain infinite animations, so avoid pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SmartBudgetApp), findsOneWidget);
  });
}
