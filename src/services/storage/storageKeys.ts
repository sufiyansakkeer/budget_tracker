export const STORAGE_KEYS = {
  ONBOARDING_COMPLETED: 'onboarding_completed',
  THEME_MODE: 'theme_mode',
  CURRENCY: 'currency',
  ACTIVE_BUDGET_ID: 'active_budget_id',
} as const;

export type StorageKey = (typeof STORAGE_KEYS)[keyof typeof STORAGE_KEYS];
