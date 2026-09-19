/** Corner radius scale, ported from `AppSpacing`'s radius constants. */
export const radius = {
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  full: 999,
} as const;

export type Radius = typeof radius;
export type RadiusToken = keyof Radius;
