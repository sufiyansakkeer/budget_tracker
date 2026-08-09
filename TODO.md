# Biometric Unlock Flow Fix - Task Tracking

## Objective
Fix the app being stuck on the biometric/fingerprint lock screen after successful
authentication. The app must transition `LOCKED → UNLOCKED` and reveal the existing
application content without restart, without navigating to `/dashboard`, and without
introducing a fixed delay.

## Root Cause
`BiometricGateScreen` held the lock state in a local boolean `_isAuthenticated` and
re-fired `_checkAndAuthenticate()` on every `resumed` lifecycle event. Dismissing the
native biometric prompt triggers a `resumed` event, which caused an endless
re-lock/re-prompt loop -> the app appeared stuck on the fingerprint screen. There was
no single authoritative lock BLoC, no concurrency guard, and no way to distinguish a
real background->foreground transition from the biometric prompt's dismissal.

## Steps
- [x] 1. Create `app_lock_state.dart` (AppLockStatus enum + AppLockState Equatable).
- [x] 2. Create `app_lock_event.dart` (AppStartLockCheck, AppUnlockRequested,
      AppAuthenticated, AppAuthFailed, AppLockRequested, AppLocked).
- [x] 3. Create `app_lock_bloc.dart` with the lock state machine, concurrency guard,
      lifecycle-aware re-lock, and debug logging.
- [x] 4. Add `authenticateNow()` to `BiometricInitializer`.
- [x] 5. Register `AppLockBloc` in `injection.dart`.
- [x] 6. Refactor `BiometricGateScreen` into a presentational widget driven by the BLoC.
- [x] 7. Refactor `main.dart` to provide `AppLockBloc` and render gate vs app content.
- [x] 8. Add `app_lock_bloc_test.dart`.
- [x] 9. Update `widget_test.dart`.
- [x] 10. Run `flutter analyze` and fix issues.
- [x] 11. Run `flutter test`.
- [x] 12. Run `flutter build debug`.
