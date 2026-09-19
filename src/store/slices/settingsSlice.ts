import { createSlice, type PayloadAction } from '@reduxjs/toolkit';
import { DEFAULT_CURRENCY_CODE } from '../../domain/currency';
import { STORAGE_KEYS } from '../../services/storage/storageKeys';
import { storageService } from '../../services/storage/storageService';
import type { ThemeMode } from '../../theme/theme';
import type { RootState } from '../store';

export interface SettingsState {
  themeMode: ThemeMode;
  currencyCode: string;
  onboardingCompleted: boolean;
  /** Which budget the dashboard and the expense form default to. */
  activeBudgetId: string | null;
}

const isThemeMode = (value: string | undefined): value is ThemeMode =>
  value === 'light' || value === 'dark' || value === 'system';

/**
 * Settings are read synchronously from MMKV at store-creation time, so the
 * first frame already renders with the user's theme and currency — no flash
 * of default styling while an async store rehydrates.
 */
function loadInitialState(): SettingsState {
  const storedMode = storageService.getString(STORAGE_KEYS.THEME_MODE);

  return {
    themeMode: isThemeMode(storedMode) ? storedMode : 'system',
    currencyCode:
      storageService.getString(STORAGE_KEYS.CURRENCY) ?? DEFAULT_CURRENCY_CODE,
    onboardingCompleted:
      storageService.getBoolean(STORAGE_KEYS.ONBOARDING_COMPLETED) ?? false,
    activeBudgetId:
      storageService.getString(STORAGE_KEYS.ACTIVE_BUDGET_ID) ?? null,
  };
}

const settingsSlice = createSlice({
  name: 'settings',
  initialState: loadInitialState,
  reducers: {
    setThemeMode: (state, action: PayloadAction<ThemeMode>) => {
      state.themeMode = action.payload;
    },
    setCurrencyCode: (state, action: PayloadAction<string>) => {
      state.currencyCode = action.payload;
    },
    setOnboardingCompleted: (state, action: PayloadAction<boolean>) => {
      state.onboardingCompleted = action.payload;
    },
    setActiveBudgetId: (state, action: PayloadAction<string | null>) => {
      state.activeBudgetId = action.payload;
    },
  },
});

export const {
  setThemeMode,
  setCurrencyCode,
  setOnboardingCompleted,
  setActiveBudgetId,
} = settingsSlice.actions;

export const selectSettings = (state: RootState) => state.settings;
export const selectThemeMode = (state: RootState) => state.settings.themeMode;
export const selectCurrencyCode = (state: RootState) =>
  state.settings.currencyCode;
export const selectOnboardingCompleted = (state: RootState) =>
  state.settings.onboardingCompleted;
export const selectActiveBudgetId = (state: RootState) =>
  state.settings.activeBudgetId;

export default settingsSlice.reducer;
