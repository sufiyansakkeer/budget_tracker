import {
  currencyByCode,
  formatMoney,
  parseMoney,
} from './currency';

describe('currencyByCode', () => {
  it('finds a supported currency', () => {
    expect(currencyByCode('OMR').symbol).toBe('ر.ع.');
  });

  it('falls back to the default instead of throwing on an unknown code', () => {
    expect(currencyByCode('XYZ').code).toBe('INR');
    expect(currencyByCode(undefined).code).toBe('INR');
  });
});

describe('formatMoney', () => {
  it('uses the currency symbol, not the locale substitution for the code', () => {
    // Intl's `style: 'currency'` would render "OMR" on an en-US device.
    expect(formatMoney(1234.5, 'OMR')).toBe('ر.ع.1,234.50');
  });

  it('keeps two decimals by default', () => {
    expect(formatMoney(80, 'INR')).toBe('₹80.00');
  });

  it('drops decimals when whole is set', () => {
    expect(formatMoney(1234.56, 'USD', { whole: true })).toBe('$1,235');
  });

  it('puts the minus sign before the symbol', () => {
    expect(formatMoney(-500, 'USD')).toBe('-$500.00');
  });

  it('marks positives when signed is set, but never double-signs negatives', () => {
    expect(formatMoney(10, 'USD', { signed: true })).toBe('+$10.00');
    expect(formatMoney(-10, 'USD', { signed: true })).toBe('-$10.00');
    expect(formatMoney(0, 'USD', { signed: true })).toBe('$0.00');
  });

  it('compacts large values', () => {
    expect(formatMoney(1200, 'USD', { compact: true })).toBe('$1.2K');
  });

  it('renders a non-finite amount as zero rather than NaN', () => {
    expect(formatMoney(Number.NaN, 'USD')).toBe('$0.00');
  });
});

describe('parseMoney', () => {
  it.each([
    ['1,234.50', 1234.5],
    ['₹80', 80],
    ['-25', -25],
    ['0', 0],
  ])('parses %p', (input, expected) => {
    expect(parseMoney(input)).toBe(expected);
  });

  it.each(['', '   ', '.', '-', 'abc'])('rejects %p', input => {
    expect(parseMoney(input)).toBeNull();
  });
});
