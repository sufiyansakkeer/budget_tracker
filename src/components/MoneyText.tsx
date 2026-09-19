import type { StyleProp, TextStyle } from 'react-native';
import { useAppSelector } from '../store/hooks';
import { selectCurrencyCode } from '../store/slices/settingsSlice';
import { formatMoney, type FormatMoneyOptions } from '../domain/currency';
import type { ColorToken } from '../theme/colors';
import type { TypographyToken } from '../theme/typography';
import { AppText } from './AppText';

interface MoneyTextProps extends FormatMoneyOptions {
  amount: number;
  /** Overrides the user's currency — used when a budget has its own. */
  currencyCode?: string;
  variant?: TypographyToken;
  color?: ColorToken;
  /** Color negatives red and positives green, ignoring `color`. */
  colorBySign?: boolean;
  style?: StyleProp<TextStyle>;
}

/** Renders an amount in the active currency, with tabular figures by default. */
export function MoneyText({
  amount,
  currencyCode,
  variant = 'money',
  color = 'textPrimary',
  colorBySign = false,
  style,
  ...formatOptions
}: MoneyTextProps) {
  const activeCurrency = useAppSelector(selectCurrencyCode);
  const code = currencyCode ?? activeCurrency;

  const resolvedColor: ColorToken = colorBySign
    ? amount < 0
      ? 'expense'
      : 'income'
    : color;

  return (
    <AppText variant={variant} color={resolvedColor} style={style}>
      {formatMoney(amount, code, formatOptions)}
    </AppText>
  );
}
