/** Selectable currencies, ported from the Flutter `CurrencyEntity` list. */
export interface Currency {
  code: string;
  symbol: string;
  name: string;
}

export const availableCurrencies: readonly Currency[] = [
  { code: 'INR', symbol: '₹', name: 'Indian Rupee' },
  { code: 'USD', symbol: '$', name: 'US Dollar' },
  { code: 'EUR', symbol: '€', name: 'Euro' },
  { code: 'AED', symbol: 'د.إ', name: 'UAE Dirham' },
  { code: 'OMR', symbol: 'ر.ع.', name: 'Omani Rial' },
  { code: 'GBP', symbol: '£', name: 'British Pound' },
  { code: 'CAD', symbol: 'C$', name: 'Canadian Dollar' },
  { code: 'AUD', symbol: 'A$', name: 'Australian Dollar' },
  { code: 'JPY', symbol: '¥', name: 'Japanese Yen' },
  { code: 'SGD', symbol: 'S$', name: 'Singapore Dollar' },
] as const;

export const DEFAULT_CURRENCY_CODE = 'INR';

/** Finds a currency by code, falling back to the default rather than throwing. */
export function currencyByCode(code: string | undefined | null): Currency {
  return (
    availableCurrencies.find(c => c.code === code) ?? availableCurrencies[0]
  );
}

export interface FormatMoneyOptions {
  /** Drop the minor units — useful for large headline figures. */
  whole?: boolean;
  /** Render as `1.2K` / `3.4M` for tight spaces like chart axes. */
  compact?: boolean;
  /** Prefix positive values with `+`. Negatives always keep their sign. */
  signed?: boolean;
}

/**
 * Formats an amount with the currency's own symbol.
 *
 * We deliberately format the *number* with `Intl` and prepend the symbol
 * ourselves: `style: 'currency'` would use the locale's symbol for the code,
 * which on a device set to en-US renders OMR as "OMR" rather than "ر.ع.".
 */
export function formatMoney(
  amount: number,
  currencyCode: string,
  options: FormatMoneyOptions = {},
): string {
  const { whole = false, compact = false, signed = false } = options;
  const { symbol } = currencyByCode(currencyCode);

  const safeAmount = Number.isFinite(amount) ? amount : 0;
  const magnitude = Math.abs(safeAmount);

  const formatted = new Intl.NumberFormat('en-US', {
    notation: compact ? 'compact' : 'standard',
    maximumFractionDigits: whole ? 0 : 2,
    minimumFractionDigits: whole || compact ? 0 : 2,
  }).format(magnitude);

  const sign = safeAmount < 0 ? '-' : signed && safeAmount > 0 ? '+' : '';
  return `${sign}${symbol}${formatted}`;
}

/** Parses user input ("1,234.50", "₹80") into a number, or null if unusable. */
export function parseMoney(input: string): number | null {
  const cleaned = input.replace(/[^0-9.-]/g, '');
  if (cleaned === '' || cleaned === '-' || cleaned === '.') {
    return null;
  }
  const value = Number(cleaned);
  return Number.isFinite(value) ? value : null;
}
