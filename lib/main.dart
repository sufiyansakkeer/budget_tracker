import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'core/currency/currency_provider.dart';
import 'core/di/injection.dart' as di;
import 'core/notifications/notification_initializer.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/biometric/biometric_gate_screen.dart';
import 'features/settings/presentation/bloc/theme/theme_bloc.dart';
import 'features/settings/presentation/bloc/theme/theme_state.dart';

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
  late final ThemeBloc _themeBloc;
  late final CurrencyProvider _currencyProvider;

  @override
  void initState() {
    super.initState();
    _themeBloc = di.getIt<ThemeBloc>();
    _currencyProvider = di.getIt<CurrencyProvider>()
      ..addListener(_onCurrencyChanged);
  }

  @override
  void dispose() {
    _currencyProvider.removeListener(_onCurrencyChanged);
    super.dispose();
  }

  void _onCurrencyChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = MultiProvider(
      providers: [ChangeNotifierProvider.value(value: _currencyProvider)],
      child: MultiBlocProvider(
        providers: [BlocProvider<ThemeBloc>.value(value: _themeBloc)],
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return MaterialApp.router(
              title: 'Smart Budget Tracker',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: state.mode.toThemeMode(),
              routerConfig: AppRouter.router,
            );
          },
        ),
      ),
    );

    // Wrap with biometric gate for authentication
    return BiometricGateScreen(child: app);
  }
}
