import { createListenerMiddleware, isAnyOf } from '@reduxjs/toolkit';
import { STORAGE_KEYS } from '../../services/storage/storageKeys';
import { storageService } from '../../services/storage/storageService';
import {
  setActiveBudgetId,
  setCurrencyCode,
  setOnboardingCompleted,
  setThemeMode,
} from '../slices/settingsSlice';

/**
 * Mirrors the settings slice into MMKV.
 *
 * This lives in middleware rather than inside the reducers because reducers
 * must stay pure — writing to storage from one would make state transitions
 * un-replayable and break time-travel debugging.
 */
export const persistSettingsMiddleware = createListenerMiddleware();

persistSettingsMiddleware.startListening({
  matcher: isAnyOf(
    setThemeMode,
    setCurrencyCode,
    setOnboardingCompleted,
    setActiveBudgetId,
  ),
  effect: action => {
    if (setThemeMode.match(action)) {
      storageService.setString(STORAGE_KEYS.THEME_MODE, action.payload);
      return;
    }
    if (setCurrencyCode.match(action)) {
      storageService.setString(STORAGE_KEYS.CURRENCY, action.payload);
      return;
    }
    if (setOnboardingCompleted.match(action)) {
      storageService.setBoolean(
        STORAGE_KEYS.ONBOARDING_COMPLETED,
        action.payload,
      );
      return;
    }
    if (setActiveBudgetId.match(action)) {
      if (action.payload === null) {
        storageService.remove(STORAGE_KEYS.ACTIVE_BUDGET_ID);
      } else {
        storageService.setString(
          STORAGE_KEYS.ACTIVE_BUDGET_ID,
          action.payload,
        );
      }
    }
  },
});
