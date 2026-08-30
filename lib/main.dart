import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'core/currency/currency_provider.dart';
import 'core/notifications/notification_bloc.dart';
import 'core/di/injection.dart' as di;
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/biometric/biometric_gate_screen.dart';
import 'core/biometric/app_lock_bloc.dart';
import 'core/biometric/app_lock_state.dart';

import 'features/app_update/presentation/bloc/app_update_bloc.dart';
import 'features/app_update/presentation/bloc/app_update_event.dart';
import 'features/app_update/presentation/bloc/app_update_state.dart';
import 'features/app_update/presentation/widgets/update_dialog_service.dart';
import 'features/settings/presentation/bloc/theme/theme_bloc.dart';
import 'features/settings/presentation/bloc/theme/theme_state.dart';
import 'features/widgets/home_widget_service.dart';
import 'features/widgets/widget_refresh_listener.dart';

/// Callback dispatcher for home_widget interactivity.
/// Must be a top-level or static function with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
void homeWidgetCallbackDispatcher(Uri? uri) {
  // Handle background widget taps if needed in the future.
}

/// Global widget refresh listener — keeps the home-screen widget current
/// after every expense or budget change.
WidgetRefreshListener? _widgetRefreshListener;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencyInjection();

  // Initialize notifications (permission + scheduling) before UI.
  await di.getIt<NotificationBloc>().initializeOnStartup();

  // ── Home Widget: configure iOS App Group for data sharing ────────────
  await _configureHomeWidget();

  // ── Home Widget: check if app was launched from a widget tap ──────────
  await _handleWidgetLaunch();

  // ── Home Widget: update widget data on every app start ────────────────
  _updateWidgetDataOnStartup();

  // ── Home Widget: register interactivity callback ──────────────────────
  await _registerWidgetCallbacks();

  // ── Home Widget: listen for data changes and refresh widget ───────────
  _widgetRefreshListener = WidgetRefreshListener(
    widgetService: HomeWidgetService.fromDI(),
  )..startListening();

  runApp(const SmartBudgetApp());
}

/// Configures the home_widget package for iOS App Group data sharing.
///
/// This MUST be called before any `saveWidgetData` calls. On iOS, the
/// `home_widget` plugin requires an App Group identifier to share data
/// between the main app and the WidgetKit extension via shared UserDefaults.
/// Without this call, all iOS data sharing fails silently.
Future<void> _configureHomeWidget() async {
  try {
    await HomeWidget.setAppGroupId('group.com.sufiyan.monivo');
  } catch (e) {
    // Configuration failed — widget data sharing won't work on iOS.
  }
}

/// Checks if the app was launched from a home-screen widget and
/// extracts the route to navigate to.
Future<void> _handleWidgetLaunch() async {
  try {
    final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (launchUri != null) {
      final route = resolveWidgetUriToRoute(launchUri);
      if (route != null) {
        setPendingWidgetRoute(route);
      }
    }
  } catch (e) {
    // Widget launch detection failed — not critical.
  }
}

/// Updates widget data on app startup so the widget shows fresh values.
void _updateWidgetDataOnStartup() {
  // Run asynchronously — don't block app launch.
  Future.microtask(() async {
    try {
      final service = HomeWidgetService.fromDI();
      await service.updateWidgetData();
    } catch (e) {
      // Widget update on startup is best-effort.
    }
  });
}

/// Registers the interactivity callback so widget taps can trigger Dart code.
Future<void> _registerWidgetCallbacks() async {
  try {
    await HomeWidget.registerInteractivityCallback(
      homeWidgetCallbackDispatcher,
    );
  } catch (e) {
    // Registration failed — widget interactivity won't work.
  }
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
  StreamSubscription<Uri?>? _widgetClickedSubscription;

  @override
  void initState() {
    super.initState();
    _themeBloc = di.getIt<ThemeBloc>();
    _currencyProvider = di.getIt<CurrencyProvider>()
      ..addListener(_onCurrencyChanged);
    _appUpdateBloc = di.getIt<AppUpdateBloc>();

    // Listen for widget clicks while app is in background/foreground (warm start)
    _widgetClickedSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) {
        final route = resolveWidgetUriToRoute(uri);
        if (route != null) {
          setPendingWidgetRoute(route);
          final lockBloc = di.getIt<AppLockBloc>();
          if (lockBloc.state.status == AppLockStatus.unlocked) {
            consumePendingWidgetRoute();
            if (route == widgetAddExpensePath) {
              AppRouter.router.push(widgetAddExpensePath);
            } else {
              AppRouter.router.go(route);
            }
          }
        }
      }
    });


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
    _widgetClickedSubscription?.cancel();
    _widgetRefreshListener?.stopListening();
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
