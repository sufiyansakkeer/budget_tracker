import {
  useNavigation,
  useRoute,
  type RouteProp,
} from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useTranslation } from 'react-i18next';
import { ActivityIndicator, ScrollView, StyleSheet, View } from 'react-native';
import { AppText } from '../../../components/AppText';
import { Button } from '../../../components/Button';
import { Card } from '../../../components/Card';
import { CategoryAvatar } from '../../../components/CategoryAvatar';
import { Chip } from '../../../components/Chip';
import { confirm } from '../../../components/ConfirmDialog';
import { EmptyState } from '../../../components/EmptyState';
import { MoneyText } from '../../../components/MoneyText';
import { Screen } from '../../../components/Screen';
import { categoryById } from '../../../domain/categories';
import { formatDate, formatTime } from '../../../domain/dates';
import type { RootStackParamList } from '../../../navigation/types';
import { useTheme } from '../../../theme/ThemeProvider';
import { useBudget } from '../../budget/hooks/useBudgets';
import {
  useCategories,
  useDeleteExpense,
  useExpense,
} from '../hooks/useExpenses';

type Navigation = NativeStackNavigationProp<RootStackParamList>;
type DetailsRoute = RouteProp<RootStackParamList, 'ExpenseDetails'>;

export function ExpenseDetailsScreen() {
  const theme = useTheme();
  const { t } = useTranslation();
  const navigation = useNavigation<Navigation>();
  const { expenseId } = useRoute<DetailsRoute>().params;

  const { data: expense, isPending } = useExpense(expenseId);
  const { data: categories = [] } = useCategories();
  const { data: budget } = useBudget(expense?.budgetId);
  const deleteExpense = useDeleteExpense();

  const handleDelete = async () => {
    const confirmed = await confirm({
      title: t('expenses.deleteTitle'),
      message: t('expenses.deleteBody'),
      confirmLabel: t('common.delete'),
      cancelLabel: t('common.cancel'),
      destructive: true,
    });
    if (!confirmed) return;

    await deleteExpense.mutateAsync(expenseId);
    navigation.goBack();
  };

  if (isPending) {
    return (
      <Screen edgeTop={false}>
        <View style={styles.centered}>
          <ActivityIndicator color={theme.colors.primary} />
        </View>
      </Screen>
    );
  }

  if (!expense) {
    return (
      <Screen edgeTop={false}>
        <EmptyState icon="receipt-long" title={t('common.somethingWentWrong')} />
      </Screen>
    );
  }

  const category = categoryById(categories, expense.categoryId);

  return (
    <Screen edgeTop={false}>
      <ScrollView contentContainerStyle={{ padding: theme.spacing.md }}>
        <Card>
          <View style={styles.header}>
            <CategoryAvatar category={category} size={56} />
            <View style={[styles.headerText, { marginLeft: theme.spacing.smd }]}>
              <AppText variant="label" color="textSecondary">
                {category.name}
              </AppText>
              <MoneyText
                amount={expense.amount}
                currencyCode={budget?.currency}
                variant="displaySmall"
              />
            </View>
          </View>
        </Card>

        <Card style={{ marginTop: theme.spacing.smd }}>
          <DetailRow label={t('expenses.date')} value={formatDate(expense.date)} />
          <DetailRow label={t('expenses.time')} value={formatTime(expense.date)} />
          {budget ? (
            <DetailRow label={t('expenses.budget')} value={budget.name} />
          ) : null}
          {expense.note ? (
            <DetailRow label={t('expenses.note')} value={expense.note} />
          ) : null}
        </Card>

        {expense.tags.length > 0 ? (
          <Card style={{ marginTop: theme.spacing.smd }}>
            <AppText variant="label" color="textSecondary">
              {t('expenses.tags')}
            </AppText>
            <View style={[styles.tagRow, { marginTop: theme.spacing.sm }]}>
              {expense.tags.map(tag => (
                <Chip key={tag} label={tag} />
              ))}
            </View>
          </Card>
        ) : null}

        <Button
          label={t('common.edit')}
          icon="edit"
          onPress={() => navigation.navigate('ExpenseForm', { expenseId })}
          style={{ marginTop: theme.spacing.lg }}
        />
        <Button
          label={t('common.delete')}
          icon="delete-outline"
          variant="danger"
          onPress={handleDelete}
          loading={deleteExpense.isPending}
          style={{ marginTop: theme.spacing.sm }}
        />
      </ScrollView>
    </Screen>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  const theme = useTheme();
  return (
    <View style={[styles.detailRow, { paddingVertical: theme.spacing.sm }]}>
      <AppText variant="body" color="textSecondary">
        {label}
      </AppText>
      <AppText variant="subtitle" style={styles.detailValue}>
        {value}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: { flexDirection: 'row', alignItems: 'center' },
  headerText: { flex: 1 },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    gap: 16,
  },
  detailValue: { flex: 1, textAlign: 'right' },
  tagRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
});
