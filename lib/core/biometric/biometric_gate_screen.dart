import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/settings/presentation/bloc/theme/theme_bloc.dart';
import '../../features/settings/presentation/bloc/theme/theme_state.dart';
import '../../features/widgets/home_widget_service.dart';
import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import 'app_lock_bloc.dart';
import 'app_lock_event.dart';
import 'app_lock_state.dart';

/// Full-screen gate shown while the application is locked.
///
/// This widget is purely presentational: it does NOT own the lock state. The
/// authoritative state lives in [AppLockBloc]. When the app is backgrounded the
/// widget dispatches [AppLockRequested] so the BLoC can re-lock; while it is
/// running the gate simply reflects the BLoC state.
///
/// The child (the real application) is only revealed when the BLoC status is
/// [AppLockStatus.unlocked]. The gate renders inside its own [MaterialApp]
/// (it sits above the router) but is themed from [ThemeBloc], so it matches
/// the user's palette and light/dark preference.
class BiometricGateScreen extends StatefulWidget {
  final Widget child;

  const BiometricGateScreen({super.key, required this.child});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kick off the initial lock check on app start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppLockBloc>().add(const AppStartLockCheck());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app is backgrounded, request the BLoC to re-lock. The BLoC
    // decides whether re-locking is appropriate (only when biometrics are
    // enabled) and guards against concurrent prompts. Simply dismissing the
    // native biometric prompt does NOT trigger this, so the app will not
    // immediately re-lock after a successful authentication.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      context.read<AppLockBloc>().add(const AppLockRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppLockBloc, AppLockState>(
      listenWhen: (previous, current) =>
          previous.status != AppLockStatus.unlocked &&
          current.status == AppLockStatus.unlocked,
      listener: (context, state) {
        final pending = consumePendingWidgetRoute();
        if (pending != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (pending == widgetAddExpensePath) {
                AppRouter.router.push(widgetAddExpensePath);
              } else {
                AppRouter.router.go(pending);
              }
            } catch (_) {}
          });
        }
      },
      builder: (context, state) {
        final locked = state.status != AppLockStatus.unlocked;
        final themeBloc = context.watch<ThemeBloc?>();
        final ThemeState? themeState = themeBloc?.state;

        // The real application stays mounted underneath the gate the whole
        // time. Unmounting it on lock would throw away every tab, scroll
        // position, route-scoped BLoC and open dialog, and every unlock would
        // then replay the cold-start skeletons. While locked the app is
        // off-stage: not painted (so nothing leaks into the app switcher),
        // not hit-testable, and its tickers are paused.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Visibility(
                visible: !locked,
                maintainState: true,
                child: widget.child,
              ),
              // Locking is instant so the content is covered before the
              // system takes its app-switcher snapshot; unlocking fades the
              // gate away over the already-restored app.
              AnimatedSwitcher(
                duration: AppMotion.respectReducedMotion(
                  context,
                  AppMotion.standard,
                ),
                switchInCurve: const Threshold(0),
                switchOutCurve: AppMotion.exit,
                child: locked
                    ? PopScope(
                        key: const ValueKey('lock_gate'),
                        // Intercept the system back button so the user cannot
                        // navigate away from the gate and bypass
                        // authentication.
                        canPop: false,
                        child: MaterialApp(
                          debugShowCheckedModeBanner: false,
                          theme: themeState == null
                              ? AppTheme.lightTheme
                              : AppTheme.buildLightTheme(themeState.palette),
                          darkTheme: themeState == null
                              ? AppTheme.darkTheme
                              : AppTheme.buildDarkTheme(themeState.palette),
                          themeMode:
                              themeState?.mode.toThemeMode() ??
                              ThemeMode.system,
                          themeAnimationDuration:
                              AppMotion.respectReducedMotion(
                                context,
                                AppMotion.medium,
                              ),
                          themeAnimationCurve: AppMotion.emphasizedCurve,
                          // The lock screen has no AppBar either, so it needs
                          // the same status-bar annotation the main app
                          // applies.
                          builder: (context, child) =>
                              AnnotatedRegion<SystemUiOverlayStyle>(
                                value: AppTheme.systemOverlayStyle(
                                  Theme.of(context).brightness,
                                ),
                                child: child ?? const SizedBox.shrink(),
                              ),
                          home: _LockScreenBody(
                            state: state,
                            onRetry: () {
                              context.read<AppLockBloc>().add(
                                const AppUnlockRequested(),
                              );
                            },
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('unlocked')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LockScreenBody extends StatelessWidget {
  final AppLockState state;
  final VoidCallback onRetry;

  const _LockScreenBody({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // This context is *inside* the gate's MaterialApp, so Theme resolves to
    // the user's palette.
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAuthenticating = state.isAuthenticating;
    final isChecking = state.status == AppLockStatus.checking;

    // While the app is still deciding whether biometrics are required (a few
    // frames after launch) show a plain surface that continues the native
    // splash. Users without biometrics then never see a lock screen flash
    // before the dashboard fades in.
    if (isChecking) {
      return const Scaffold(body: SizedBox.expand());
    }

    final message = isAuthenticating ? 'Authenticating…' : 'Unlock to continue';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: AppSizes.avatarXl,
                    height: AppSizes.avatarXl,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: AppSizes.iconHero,
                      color: colorScheme.onPrimaryContainer,
                      semanticLabel: 'Biometric lock',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Monivo',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: AnimatedSwitcher(
                      duration: AppMotion.respectReducedMotion(
                        context,
                        AppMotion.standard,
                      ),
                      child: Text(
                        message,
                        key: ValueKey(message),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AnimatedSwitcher(
                    duration: AppMotion.respectReducedMotion(
                      context,
                      AppMotion.standard,
                    ),
                    child: isAuthenticating || isChecking
                        ? const SizedBox(
                            key: ValueKey('progress'),
                            height: AppSizes.touchTarget,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Column(
                            key: const ValueKey('actions'),
                            children: [
                              if (state.errorMessage != null) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: AppSizes.iconSm,
                                      color: colorScheme.error,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Flexible(
                                      child: Text(
                                        state.errorMessage!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: colorScheme.error,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              // Always-available re-authentication action so the
                              // user can retry even after dismissing the native
                              // biometric prompt.
                              FilledButton.icon(
                                onPressed: onRetry,
                                icon: const Icon(Icons.fingerprint_rounded),
                                label: const Text('Unlock'),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
