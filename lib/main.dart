import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'core/currency/currency_provider.dart';
import 'core/notifications/notification_bloc.dart';
import 'core/di/injection.dart' as di;
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/biometric/biometric_gate_screen.dart';
import 'core/biometric/app_lock_bloc.dart';
import 'features/app_update/presentation/bloc/app_update_bloc.dart';
import 'features/app_update/presentation/bloc/app_update_event.dart';
import 'features/app_update/presentation/bloc/app_update_state.dart';
import 'features/app_update/presentation/widgets/update_dialog_service.dart';
import 'features/settings/presentation/bloc/theme/theme_bloc.dart';
import 'features/settings/presentation/bloc/theme/theme_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencyInjection();

  // Initialize notifications (permission + scheduling) before UI.
  await di.getIt<NotificationBloc>().initializeOnStartup();

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
  late final AppUpdateBloc _appUpdateBloc;

  @override
  void initState() {
    super.initState();
    _themeBloc = di.getIt<ThemeBloc>();
    _currencyProvider = di.getIt<CurrencyProvider>()
      ..addListener(_onCurrencyChanged);
    _appUpdateBloc = di.getIt<AppUpdateBloc>();

    // Trigger update check asynchronously after the first frame renders
    // so the app never blocks on a slow network.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appUpdateBloc.add(const AppUpdateCheckOnLaunch());
    });
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
    return BlocProvider<AppLockBloc>.value(
      value: di.getIt<AppLockBloc>(),
      child: BiometricGateScreen(
        child: BlocProvider<AppUpdateBloc>.value(
          value: _appUpdateBloc,
          child: MultiProvider(
            providers: [ChangeNotifierProvider.value(value: _currencyProvider)],
            child: BlocProvider<ThemeBloc>.value(
              value: _themeBloc,
              child: BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, state) {
                  return MaterialApp.router(
                    title: 'Smart Monivo',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.lightTheme,
                    darkTheme: AppTheme.darkTheme,
                    themeMode: state.mode.toThemeMode(),
                    routerConfig: AppRouter.router,
                    // The builder places a BlocListener *inside* the
                    // MaterialApp tree.  The context here is below
                    // MaterialLocalizations but above the Navigator,
                    // so we must NOT call showDialog with it directly.
                    // Instead we use UpdateDialogService, which obtains a
                    // valid Navigator context through the root navigator key
                    // registered on GoRouter.
                    builder: (context, child) {
                      return BlocListener<AppUpdateBloc, AppUpdateState>(
                        listenWhen: (previous, current) {
                          // Only listen for the *first* time an update is
                          // available after launch; ignore subsequent state
                          // transitions (e.g. up-to-date after manual check).
                          if (current is! AppUpdateAvailable) return false;
                          if (previous is AppUpdateAvailable) return false;
                          return true;
                        },
                        listener: (context, state) {
                          if (state is AppUpdateAvailable) {
                            UpdateDialogService.show(state.result);
                          }
                        },
                        child: child ?? const SizedBox.shrink(),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
