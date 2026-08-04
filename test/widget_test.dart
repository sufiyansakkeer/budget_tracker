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
    await tester.pumpWidget(const SmartBudgetApp());
    await tester.pumpAndSettle();
    expect(find.text('Dashboard Feature Placeholder'), findsOneWidget);
  });
}
