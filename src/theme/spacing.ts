/**
 * Spacing scale (4 → 8 → 12 → 16 → 24 → 32 → 48), ported from `AppSpacing`.
 *
 * Prefer these tokens over ad-hoc margins so every screen shares one rhythm.
 */
export const spacing = {
  xs: 4,
  sm: 8,
  smd: 12,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
} as const;

export type Spacing = typeof spacing;
export type SpacingToken = keyof Spacing;
