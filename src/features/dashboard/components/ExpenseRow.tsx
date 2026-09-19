import { StyleSheet, View } from 'react-native';
import { AppText } from '../../../components/AppText';
import { CategoryAvatar } from '../../../components/CategoryAvatar';
import { MoneyText } from '../../../components/MoneyText';
import type { Category } from '../../../domain/categories';
import { formatTime } from '../../../domain/dates';
import type { Expense } from '../../../domain/types';
import { useTheme } from '../../../theme/ThemeProvider';

interface ExpenseRowProps {
  expense: Expense;
  category: Category;
  currencyCode?: string;
}

/** One expense line: category badge, note/category name, time, amount. */
export function ExpenseRow({ expense, category, currencyCode }: ExpenseRowProps) {
  const theme = useTheme();

  return (
    <View style={[styles.row, { paddingVertical: theme.spacing.sm }]}>
      <CategoryAvatar category={category} />
      <View style={[styles.details, { marginHorizontal: theme.spacing.smd }]}>
        <AppText variant="subtitle" numberOfLines={1}>
          {expense.note?.trim() || category.name}
        </AppText>
        <AppText variant="caption" color="textTertiary">
          {expense.note?.trim()
            ? `${category.name} · ${formatTime(expense.date)}`
            : formatTime(expense.date)}
        </AppText>
      </View>
      <MoneyText
        amount={expense.amount}
        currencyCode={currencyCode}
        variant="subtitle"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center' },
  details: { flex: 1 },
});
