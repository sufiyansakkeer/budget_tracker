import { useCallback } from 'react';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useTranslation } from 'react-i18next';
import {
  ActivityIndicator,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '../../../components/AppText';
import { Button } from '../../../components/Button';
import { Card } from '../../../components/Card';
import { EmptyState } from '../../../components/EmptyState';
import { Icon } from '../../../components/Icon';
import { Screen } from '../../../components/Screen';
import { SectionHeader } from '../../../components/SectionHeader';
import { categoryById } from '../../../domain/categories';
import { formatMoney } from '../../../domain/currency';
import { formatDate } from '../../../domain/dates';
import type { RootStackParamList } from '../../../navigation/types';
import { useAppSelector } from '../../../store/hooks';
import { selectActiveBudgetId } from '../../../store/slices/settingsSlice';
import { useTheme } from '../../../theme/ThemeProvider';
import { useCategories } from '../../expenses/hooks/useExpenses';
import { BudgetHeroCard } from '../components/BudgetHeroCard';
import { ExpenseRow } from '../components/ExpenseRow';
import { StatTile } from '../components/StatTile';
import { useDashboardSummary } from '../hooks/useDashboardSummary';

type Navigation = NativeStackNavigationProp<RootStackParamList>;

export function DashboardScreen() {
  const theme = useTheme();
  const { t } = useTranslation();
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<Navigation>();
  const activeBudgetId = useAppSelector(selectActiveBudgetId);

  const { data, isPending, isRefetching, refetch, isError } =
    useDashboardSummary(activeBudgetId);
  const { data: categories = [] } = useCategories();

  const openExpenseForm = useCallback(() => {
    navigation.navigate('ExpenseForm', { budgetId: data?.budget?.id });
  }, [navigation, data?.budget?.id]);

  if (isPending) {
    return (
      <Screen>
        <View style={styles.centered}>
          <ActivityIndicator color={theme.colors.primary} />
        </View>
      </Screen>
    );
  }

  if (isError) {
    return (
      <Screen>
        <EmptyState
          icon="error-outline"
          title={t('common.somethingWentWrong')}
          actionLabel={t('common.retry')}
          onAction={() => refetch()}
        />
      </Screen>
    );
  }

  const { budget, summary, recentExpenses } = data;

  if (!budget || !summary) {
    return (
      <Screen>
        <EmptyState
          icon="account-balance-wallet"
          title={t('dashboard.noBudgetTitle')}
          body={t('dashboard.noBudgetBody')}
          actionLabel={t('dashboard.createBudget')}
          onAction={() => navigation.navigate('BudgetForm')}
        />
      </Screen>
    );
  }

  const overspentToday = summary.todayOverspending > 0;
  const projectedOverspend = summary.projectedOverspending > 0;

  return (
    <Screen>
      <ScrollView
        contentContainerStyle={{
          padding: theme.spacing.md,
          paddingBottom: insets.bottom + theme.spacing.xxl,
        }}
        refreshControl={
          <RefreshControl
            refreshing={isRefetching}
            onRefresh={() => {
              refetch();
            }}
            tintColor={theme.colors.primary}
          />
        }
      >
        <View style={styles.header}>
          <View>
            <AppText variant="label" color="textSecondary">
              {t('dashboard.greeting')}
            </AppText>
            <AppText variant="headline">
              {formatDate(budget.startDate)} – {formatDate(budget.endDate)}
            </AppText>
          </View>
          <Pressable
            onPress={() => navigation.navigate('BudgetDetails', { budgetId: budget.id })}
            hitSlop={8}
            accessibilityRole="button"
            accessibilityLabel={t('budgets.title')}
          >
            <Icon name="more-horiz" size={24} color="textSecondary" />
          </Pressable>
        </View>

        <View style={{ marginTop: theme.spacing.md }}>
          <BudgetHeroCard budget={budget} summary={summary} />
        </View>

        <Card style={{ marginTop: theme.spacing.smd }}>
          <View style={styles.todayRow}>
            <View style={styles.flex}>
              <AppText variant="label" color="textSecondary">
                {t('dashboard.spentToday')}
              </AppText>
              <AppText variant="money" style={{ marginTop: theme.spacing.xs }}>
                {formatMoney(summary.todaySpent, budget.currency)}
              </AppText>
            </View>
            <Icon
              name={overspentToday ? 'trending-up' : 'check-circle'}
              size={28}
              color={overspentToday ? 'error' : 'success'}
            />
          </View>
          <AppText
            variant="caption"
            color={overspentToday ? 'error' : 'success'}
            style={{ marginTop: theme.spacing.xs }}
          >
            {overspentToday
              ? t('dashboard.overspentToday', {
                  amount: formatMoney(summary.todayOverspending, budget.currency),
                })
              : t('dashboard.withinAllowance')}
          </AppText>
        </Card>

        <View style={[styles.statRow, { marginTop: theme.spacing.smd }]}>
          <StatTile
            icon="timeline"
            label={t('dashboard.averageDailyLabel')}
            value={formatMoney(summary.averageDaily, budget.currency, { whole: true })}
            tint="info"
          />
          <StatTile
            icon={projectedOverspend ? 'warning' : 'savings'}
            label={
              projectedOverspend
                ? t('dashboard.projectedOverspendLabel')
                : t('dashboard.projectedSavingsLabel')
            }
            value={formatMoney(
              projectedOverspend
                ? summary.projectedOverspending
                : summary.projectedSavings,
              budget.currency,
              { whole: true },
            )}
            tint={projectedOverspend ? 'warning' : 'success'}
          />
        </View>

        <View style={{ marginTop: theme.spacing.lg }}>
          <SectionHeader
            title={t('dashboard.recentExpenses')}
            actionLabel={recentExpenses.length > 0 ? t('dashboard.seeAll') : undefined}
            onAction={() =>
              navigation.navigate('Main', {
                screen: 'Expenses',
                params: { budgetId: budget.id },
              })
            }
          />
          <Card padded={false} style={{ paddingHorizontal: theme.spacing.md }}>
            {recentExpenses.length === 0 ? (
              <View style={{ paddingVertical: theme.spacing.lg }}>
                <AppText variant="body" color="textSecondary" align="center">
                  {t('dashboard.noExpensesBody')}
                </AppText>
              </View>
            ) : (
              recentExpenses.map((expense, index) => (
                <Pressable
                  key={expense.id}
                  onPress={() =>
                    navigation.navigate('ExpenseDetails', { expenseId: expense.id })
                  }
                  accessibilityRole="button"
                  style={
                    index > 0 && {
                      borderTopWidth: StyleSheet.hairlineWidth,
                      borderTopColor: theme.colors.divider,
                    }
                  }
                >
                  <ExpenseRow
                    expense={expense}
                    category={categoryById(categories, expense.categoryId)}
                    currencyCode={budget.currency}
                  />
                </Pressable>
              ))
            )}
          </Card>
        </View>

        <Button
          label={t('dashboard.addExpense')}
          icon="add"
          onPress={openExpenseForm}
          style={{ marginTop: theme.spacing.lg }}
        />
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  todayRow: { flexDirection: 'row', alignItems: 'center' },
  statRow: { flexDirection: 'row', gap: 12 },
});
