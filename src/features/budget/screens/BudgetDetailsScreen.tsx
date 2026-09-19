import { useMemo } from 'react';
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
import { confirm } from '../../../components/ConfirmDialog';
import { EmptyState } from '../../../components/EmptyState';
import { MoneyText } from '../../../components/MoneyText';
import { ProgressBar } from '../../../components/ProgressBar';
import { Screen } from '../../../components/Screen';
import { SectionHeader } from '../../../components/SectionHeader';
import { summarizeBudget } from '../../../domain/budget/calculations';
import { categoryById } from '../../../domain/categories';
import { formatDate } from '../../../domain/dates';
import type { RootStackParamList } from '../../../navigation/types';
import { useAppDispatch, useAppSelector } from '../../../store/hooks';
import {
  selectActiveBudgetId,
  setActiveBudgetId,
} from '../../../store/slices/settingsSlice';
import type { ColorToken } from '../../../theme/colors';
import { useTheme } from '../../../theme/ThemeProvider';
import { totalsByCategory } from '../../../domain/expenses';
import { useCategories, useExpenses } from '../../expenses/hooks/useExpenses';
import {
  useArchiveBudget,
  useBudget,
  useDeleteBudget,
} from '../hooks/useBudgets';

type Navigation = NativeStackNavigationProp<RootStackParamList>;
type DetailsRoute = RouteProp<RootStackParamList, 'BudgetDetails'>;

const STATUS_COLOR: Record<string, ColorToken> = {
  underBudget: 'success',
  nearLimit: 'warning',
  overBudget: 'error',
};

export function BudgetDetailsScreen() {
  const theme = useTheme();
  const { t } = useTranslation();
  const navigation = useNavigation<Navigation>();
  const { budgetId } = useRoute<DetailsRoute>().params;

  const dispatch = useAppDispatch();
  const activeBudgetId = useAppSelector(selectActiveBudgetId);

  const { data: budget, isPending } = useBudget(budgetId);
  const { data: categories = [] } = useCategories();
  const archiveBudget = useArchiveBudget();
  const deleteBudget = useDeleteBudget();

  const expenseFilter = useMemo(
    () =>
      budget
        ? { budgetId: budget.id, from: budget.startDate, to: budget.endDate }
        : { budgetId: '' },
    [budget],
  );
  const { data: expenses = [] } = useExpenses(expenseFilter);

  const summary = useMemo(() => {
    if (!budget) return null;
    const totalSpent = expenses.reduce((sum, item) => sum + item.amount, 0);
    const today = new Date().toDateString();
    const todaySpent = expenses
      .filter(item => item.date.toDateString() === today)
      .reduce((sum, item) => sum + item.amount, 0);

    return summarizeBudget(
      {
        amount: budget.amount,
        startDate: budget.startDate,
        endDate: budget.endDate,
      },
      totalSpent,
      todaySpent,
    );
  }, [budget, expenses]);

  const breakdown = useMemo(() => totalsByCategory(expenses), [expenses]);

  const handleArchive = async () => {
    if (!budget) return;
    if (!budget.isArchived) {
      const confirmed = await confirm({
        title: t('budgets.archiveTitle'),
        message: t('budgets.archiveBody'),
        confirmLabel: t('common.archive'),
        cancelLabel: t('common.cancel'),
      });
      if (!confirmed) return;
    }
    await archiveBudget.mutateAsync({
      id: budget.id,
      isArchived: !budget.isArchived,
    });
  };

  const handleDelete = async () => {
    const confirmed = await confirm({
      title: t('budgets.deleteTitle'),
      message: t('budgets.deleteBody'),
      confirmLabel: t('common.delete'),
      cancelLabel: t('common.cancel'),
      destructive: true,
    });
    if (!confirmed) return;

    await deleteBudget.mutateAsync(budgetId);
    // Leaving a deleted id selected would strand the dashboard on an empty state.
    if (activeBudgetId === budgetId) {
      dispatch(setActiveBudgetId(null));
    }
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

  if (!budget || !summary) {
    return (
      <Screen edgeTop={false}>
        <EmptyState icon="error-outline" title={t('common.somethingWentWrong')} />
      </Screen>
    );
  }

  const statusColor = STATUS_COLOR[summary.status];
  const isActive = budget.id === activeBudgetId;

  return (
    <Screen edgeTop={false}>
      <ScrollView contentContainerStyle={{ padding: theme.spacing.md }}>
        <Card>
          <AppText variant="headline">{budget.name}</AppText>
          <AppText variant="caption" color="textTertiary">
            {t('budgets.period', {
              start: formatDate(budget.startDate),
              end: formatDate(budget.endDate),
            })}
          </AppText>

          <View style={{ marginTop: theme.spacing.md }}>
            <MoneyText
              amount={summary.remaining}
              currencyCode={budget.currency}
              variant="displaySmall"
              color={summary.remaining < 0 ? 'error' : 'textPrimary'}
            />
            <AppText variant="caption" color="textSecondary">
              {t('dashboard.remaining')}
            </AppText>
          </View>

          <View style={{ marginTop: theme.spacing.md }}>
            <ProgressBar progress={summary.utilization} color={statusColor} />
          </View>

          <View style={[styles.metrics, { marginTop: theme.spacing.md }]}>
            <Metric
              label={t('dashboard.spent')}
              value={summary.totalSpent}
              currency={budget.currency}
            />
            <Metric
              label={t('dashboard.safeToSpend')}
              value={summary.dailyAllowance}
              currency={budget.currency}
            />
            <Metric
              label={t('dashboard.averageDailyLabel')}
              value={summary.averageDaily}
              currency={budget.currency}
            />
          </View>
        </Card>

        {budget.notes ? (
          <Card style={{ marginTop: theme.spacing.smd }}>
            <AppText variant="label" color="textSecondary">
              {t('budgets.notes')}
            </AppText>
            <AppText variant="body" style={{ marginTop: theme.spacing.xs }}>
              {budget.notes}
            </AppText>
          </Card>
        ) : null}

        {breakdown.length > 0 ? (
          <View style={{ marginTop: theme.spacing.lg }}>
            <SectionHeader title={t('expenses.category')} />
            <Card>
              {breakdown.map((entry, index) => {
                const category = categoryById(categories, entry.categoryId);
                const share =
                  summary.totalSpent > 0 ? entry.total / summary.totalSpent : 0;

                return (
                  <View
                    key={entry.categoryId}
                    style={[
                      styles.breakdownRow,
                      index > 0 && {
                        marginTop: theme.spacing.smd,
                        paddingTop: theme.spacing.smd,
                        borderTopWidth: StyleSheet.hairlineWidth,
                        borderTopColor: theme.colors.divider,
                      },
                    ]}
                  >
                    <CategoryAvatar category={category} size={36} />
                    <View style={[styles.flex, { marginHorizontal: theme.spacing.smd }]}>
                      <AppText variant="subtitle">{category.name}</AppText>
                      <AppText variant="caption" color="textTertiary">
                        {Math.round(share * 100)}% ·{' '}
                        {t('expenses.count', { count: entry.count })}
                      </AppText>
                    </View>
                    <MoneyText
                      amount={entry.total}
                      currencyCode={budget.currency}
                      variant="subtitle"
                    />
                  </View>
                );
              })}
            </Card>
          </View>
        ) : null}

        <Button
          label={t('common.edit')}
          icon="edit"
          onPress={() => navigation.navigate('BudgetForm', { budgetId })}
          style={{ marginTop: theme.spacing.lg }}
        />
        {!isActive && !budget.isArchived ? (
          <Button
            label={t('budgets.setActive')}
            icon="check-circle"
            variant="secondary"
            onPress={() => dispatch(setActiveBudgetId(budget.id))}
            style={{ marginTop: theme.spacing.sm }}
          />
        ) : null}
        <Button
          label={budget.isArchived ? t('common.unarchive') : t('common.archive')}
          icon="archive"
          variant="secondary"
          onPress={handleArchive}
          loading={archiveBudget.isPending}
          style={{ marginTop: theme.spacing.sm }}
        />
        <Button
          label={t('common.delete')}
          icon="delete-outline"
          variant="danger"
          onPress={handleDelete}
          loading={deleteBudget.isPending}
          style={{ marginTop: theme.spacing.sm }}
        />
      </ScrollView>
    </Screen>
  );
}

function Metric({
  label,
  value,
  currency,
}: {
  label: string;
  value: number;
  currency: string;
}) {
  return (
    <View style={styles.flex}>
      <AppText variant="caption" color="textTertiary" numberOfLines={1}>
        {label}
      </AppText>
      <MoneyText
        amount={value}
        currencyCode={currency}
        variant="label"
        whole
      />
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  metrics: { flexDirection: 'row', gap: 12 },
  breakdownRow: { flexDirection: 'row', alignItems: 'center' },
});
