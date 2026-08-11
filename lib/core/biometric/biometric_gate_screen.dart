import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
/// [AppLockStatus.unlocked].
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
    return BlocBuilder<AppLockBloc, AppLockState>(
      builder: (context, state) {
        // Unlocked -> reveal the real application content.
        if (state.status == AppLockStatus.unlocked) {
          return widget.child;
        }

        // Otherwise show the lock gate.
        final isAuthenticating = state.isAuthenticating;
        String message;
        if (isAuthenticating) {
          message = 'Authenticating…';
        } else if (state.status == AppLockStatus.checking) {
          message = 'Loading…';
        } else {
          message = 'Authenticate to continue';
        }

        // While the app is locked, intercept the system back button so the
        // user cannot navigate away from the biometric gate and bypass
        // authentication. They must authenticate (or tap Re-authenticate).
        return PopScope(
          canPop: false,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isAuthenticating
                            ? Icons.fingerprint
                            : Icons.fingerprint,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Budget Tracker',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (isAuthenticating)
                        const CircularProgressIndicator()
                      else ...[
                        if (state.errorMessage != null) ...[
                          Text(
                            state.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Always-available re-authentication action so the user
                        // can retry even after dismissing the native biometric
                        // prompt (e.g. pressing the device back button).
                        FilledButton.icon(
                          onPressed: () {
                            context.read<AppLockBloc>().add(
                              const AppUnlockRequested(),
                            );
                          },
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Re-authenticate'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
