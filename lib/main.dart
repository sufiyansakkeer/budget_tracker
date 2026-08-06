import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/di/injection.dart' as di;
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/currency/currency_provider.dart';
import 'core/notifications/notification_initializer.dart';
import 'core/biometric/biometric_gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencyInjection();

  // Initialize notifications
  final notificationInitializer = di.getIt<NotificationInitializer>();
  await notificationInitializer.initialize();

  runApp(const SmartBudgetApp());
}

class SmartBudgetApp extends StatefulWidget {
  const SmartBudgetApp({super.key});

  @override
  State<SmartBudgetApp> createState() => _SmartBudgetAppState();
}

class _SmartBudgetAppState extends State<SmartBudgetApp> {
  late final ThemeProvider _themeProvider;
  late final CurrencyProvider _currencyProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = di.getIt<ThemeProvider>()..addListener(_onThemeChanged);
    _currencyProvider = di.getIt<CurrencyProvider>()
      ..addListener(_onCurrencyChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    _currencyProvider.removeListener(_onCurrencyChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _onCurrencyChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider),
        ChangeNotifierProvider.value(value: _currencyProvider),
      ],
      child: MaterialApp.router(
        title: 'Smart Budget Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeProvider.flutterThemeMode,
        routerConfig: AppRouter.router,
      ),
    );

    // Wrap with biometric gate for authentication
    return BiometricGateScreen(child: app);
  }
}
