import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/settings/presentation/bloc/theme/theme_bloc.dart';
import '../../features/settings/presentation/bloc/theme/theme_state.dart';
import '../../features/widgets/home_widget_service.dart';
import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import '../platform/system_ui_session.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_animated_size.dart';
import 'app_lock_bloc.dart';
import 'app_lock_event.dart';
import 'app_lock_state.dart';

/// Full-screen gate shown while the application is locked.
///
/// This widget is purely presentational: it does NOT own the lock state. The
/// authoritative state lives in [AppLockBloc]. When the app comes back from
/// the background after [lockGracePeriod] the widget dispatches
/// [AppLockRequested] so the BLoC can re-lock, then [AppReturned] so a locked
/// app prompts at once; while it is running the gate simply reflects the
/// BLoC state.
///
/// The child (the real application) is only revealed when the BLoC status is
/// [AppLockStatus.unlocked]. The gate renders inside its own [MaterialApp]
/// (it sits above the router) but is themed from [ThemeBloc], so it matches
/// the user's palette and light/dark preference.
class BiometricGateScreen extends StatefulWidget {
  final Widget child;

  const BiometricGateScreen({super.key, required this.child});

  /// How long the app can be in the background (a quick look at a message,
  /// copying a number from another app) before it locks.
  static const Duration lockGracePeriod = Duration(seconds: 30);

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

  /// When a lock was skipped because the app had opened a system screen
  /// itself (a file picker, the share sheet, the camera).
  DateTime? _lockSkippedAt;

  /// When the user left the app (it went to the background).
  DateTime? _leftAt;

  /// Covers the app while it is away with the lock on, so the app-switcher
  /// snapshot shows no figures even inside the grace period.
  bool _covered = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bloc = context.read<AppLockBloc>();
    // Only leaving the app counts. `inactive` alone is a system prompt,
    // the notification shade or Control Center over the app; locking there
    // put every permission dialog and export behind the gate.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      // A system screen the app opened itself is not leaving the app:
      // locking there hid every export, import and restore result behind
      // the gate.
      if (SystemUiSession.isActive) {
        _lockSkippedAt ??= SystemUiSession.now();
        return;
      }
      // Nor is the unlock prompt's own screen (Android's PIN pad).
      if (bloc.state.isAuthenticating) return;
      _leftAt ??= SystemUiSession.now();
      if (bloc.lockEnabled && !_covered) setState(() => _covered = true);
    } else if (state == AppLifecycleState.resumed) {
      final now = SystemUiSession.now();
      final skipped = _lockSkippedAt;
      final left = _leftAt;
      _lockSkippedAt = null;
      _leftAt = null;
      if (_covered) setState(() => _covered = false);
      // A system screen left open longer than a session allows locks on
      // return, so it is never a way around the lock. An ordinary trip
      // away locks after the grace period. The bloc decides whether the
      // lock is on at all.
      if ((skipped != null &&
              now.difference(skipped) > SystemUiSession.maxDuration) ||
          (left != null &&
              now.difference(left) >= BiometricGateScreen.lockGracePeriod)) {
        bloc.add(const AppLockRequested());
      }
      if (skipped != null || left != null) bloc.add(const AppReturned());
      bloc.add(const AppLockSyncRequested());
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
              AppRouter.openFromWidget(pending);
            } catch (e) {
              debugPrint('[error] Opening $pending from the widget: $e');
            }
          });
        }
      },
      builder: (context, state) {
        final locked = state.status != AppLockStatus.unlocked;
        final hidden = locked || _covered;
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
                visible: !hidden,
                maintainState: true,
                child: widget.child,
              ),
              // Covering is instant so the content is hidden before the
              // system takes its app-switcher snapshot; unlocking (or coming
              // back inside the grace period) fades the gate away over the
              // already-restored app.
              AnimatedSwitcher(
                duration: AppMotion.respectReducedMotion(
                  context,
                  AppMotion.standard,
                ),
                switchInCurve: const Threshold(0),
                switchOutCurve: AppMotion.exit,
                child: hidden
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
                          // Away inside the grace period: a plain surface,
                          // no lock screen to flash on a quick return.
                          home: locked
                              ? _LockScreenBody(
                                  state: state,
                                  onRetry: () {
                                    context.read<AppLockBloc>().add(
                                      const AppUnlockRequested(),
                                    );
                                  },
                                )
                              : const Scaffold(body: SizedBox.expand()),
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

    // No spinner: the system prompt is the activity. The screen stays
    // still behind it, with the button in place but resting.
    final message = isAuthenticating
        ? "Confirm it's you"
        : 'Unlock to continue';

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
                  AppAnimatedSize(
                    duration: AppMotion.respectReducedMotion(
                      context,
                      AppMotion.standard,
                    ),
                    alignment: Alignment.topCenter,
                    child: state.errorMessage == null || isAuthenticating
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            // Announced when it appears. The icon sits in
                            // the text, so it stays beside the centred
                            // first line instead of the row's far edge.
                            child: Semantics(
                              liveRegion: true,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              end: AppSpacing.xs,
                                            ),
                                        child: Icon(
                                          Icons.error_outline_rounded,
                                          size: AppSizes.iconSm,
                                          color: colorScheme.error,
                                        ),
                                      ),
                                    ),
                                    TextSpan(text: state.errorMessage),
                                  ],
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ),
                  // Always available, so the user can retry after dismissing
                  // the system prompt; resting while the prompt is open.
                  FilledButton.icon(
                    onPressed: isAuthenticating ? null : onRetry,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Unlock'),
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
