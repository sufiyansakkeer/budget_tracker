# TODO - Fix Onboarding Continue Button After Clearing and Re-entering Input

## Root Cause
`OnboardingState.copyWith` uses `??` which cannot distinguish "not provided"
from "explicitly null". When the BLoC passes `null` to clear a validation
error, the old non-null error is retained, so `isBudgetValid` stays `false`
and the Continue button stays disabled after re-entering a valid value.

## Steps

- [x] Inspect onboarding BLoC, state, events, and widgets
- [x] Confirm root cause in `OnboardingState.copyWith`
- [x] Fix `copyWith` in `onboarding_state.dart` (add `clearParsedBudget`)
- [x] Update `onboarding_bloc.dart` to use clear flags on all transitions
- [x] Add BLoC tests (`onboarding_bloc_test.dart`)
- [x] Add widget test (`onboarding_continue_test.dart`)
- [x] Run `flutter analyze` (only pre-existing warnings in unrelated files)
- [x] Run `flutter test` (all onboarding tests pass; unrelated pre-existing failures remain)
- [x] Manual reproduction (covered by widget test reproducing the exact flow)
