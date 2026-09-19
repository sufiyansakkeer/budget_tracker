import { useState } from 'react';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useTranslation } from 'react-i18next';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  RefreshControl,
  StyleSheet,
  Switch,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '../../../components/AppText';
import { Card } from '../../../components/Card';
import { EmptyState } from '../../../components/EmptyState';
import { Icon } from '../../../components/Icon';
import { MoneyText } from '../../../components/MoneyText';
import { ProgressBar } from '../../../components/ProgressBar';
import { Screen } from '../../../components/Screen';
import { formatDate } from '../../../domain/dates';
import type { RootStackParamList } from '../../../navigation/types';
import { useAppDispatch, useAppSelector } from '../../../store/hooks';
import {
  selectActiveBudgetId,
  setActiveBudgetId,
} from '../../../store/slices/settingsSlice';
import type { ColorToken } from '../../../theme/colors';
import { useTheme } from '../../../theme/ThemeProvider';
import type { BudgetWithSummary } from '../api/budgetRepository';
import { useBudgetSummaries } from '../hooks/useBudgets';

type Navigation = NativeStackNavigationProp<RootStackParamList>;

const STATUS_COLOR: Record<string, ColorToken> = {
  underBudget: 'success',
  nearLimit: 'warning',
  overBudget: 'error',
};

export function BudgetListScreen() {
  const theme = useTheme();
  const { t } = useTranslation();
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<Navigation>();
  const dispatch = useAppDispatch();
  const activeBudgetId = useAppSelector(selectActiveBudgetId);

  const [showArchived, setShowArchived] = useState(false);
  const { data: items = [], isPending, isRefetching, refetch } =
    useBudgetSummaries(showArchived);

  const renderItem = ({ item }: { item: BudgetWithSummary }) => {
    const { budget, summary } = item;
    const isActive = budget.id === activeBudgetId;
    const statusColor = STATUS_COLOR[summary.status];

    return (
      <Card
        onPress={() => navigation.navigate('BudgetDetails', { budgetId: budget.id })}
        onLongPress={() => dispatch(setActiveBudgetId(budget.id))}
        accessibilityLabel={budget.name}
        style={{ marginBottom: theme.spacing.smd }}
      >
        <View style={styles.cardHeader}>
          <View style={styles.flex}>
            <View style={styles.nameRow}>
              <AppText variant="title" numberOfLines={1}>
                {budget.name}
              </AppText>
              {isActive ? (
                <View
                  style={[
                    styles.activeDot,
                    { backgroundColor: theme.colors.primary },
                  ]}
                />
              ) : null}
            </View>
            <AppText variant="caption" color="textTertiary">
              {t('budgets.period', {
                start: formatDate(budget.startDate),
                end: formatDate(budget.endDate),
              })}
            </AppText>
          </View>
          {budget.isArchived ? (
            <Icon name="archive" size={18} color="textTertiary" />
          ) : null}
        </View>

        <View style={{ marginTop: theme.spacing.smd }}>
          <ProgressBar progress={summary.utilization} color={statusColor} />
        </View>

        <View style={[styles.footerRow, { marginTop: theme.spacing.sm }]}>
          <AppText variant="caption" color="textSecondary">
            {t('dashboard.spent')}
          </AppText>
          <View style={styles.amounts}>
            <MoneyText
              amount={summary.totalSpent}
              currencyCode={budget.currency}
              variant="label"
              color={statusColor}
            />
            <AppText variant="label" color="textTertiary">
              {' / '}
            </AppText>
            <MoneyText
              amount={budget.amount}
              currencyCode={budget.currency}
              variant="label"
              color="textSecondary"
            />
          </View>
        </View>
      </Card>
    );
  };

  return (
    <Screen>
      <View style={{ padding: theme.spacing.md, paddingBottom: theme.spacing.sm }}>
        <AppText variant="headline">{t('budgets.title')}</AppText>
        <View style={[styles.archiveRow, { marginTop: theme.spacing.smd }]}>
          <AppText variant="body" color="textSecondary">
            {t('budgets.showArchived')}
          </AppText>
          <Switch
            value={showArchived}
            onValueChange={setShowArchived}
            trackColor={{
              false: theme.colors.surfaceContainerHigh,
              true: theme.colors.primary,
            }}
            accessibilityLabel={t('budgets.showArchived')}
          />
        </View>
      </View>

      {isPending ? (
        <View style={styles.centered}>
          <ActivityIndicator color={theme.colors.primary} />
        </View>
      ) : (
        <FlatList
          data={items}
          keyExtractor={item => item.budget.id}
          renderItem={renderItem}
          contentContainerStyle={{
            paddingHorizontal: theme.spacing.md,
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
          ListEmptyComponent={
            <EmptyState
              icon="account-balance-wallet"
              title={t('budgets.emptyTitle')}
              body={t('budgets.emptyBody')}
              actionLabel={t('budgets.add')}
              onAction={() => navigation.navigate('BudgetForm')}
            />
          }
        />
      )}

      <Pressable
        onPress={() => navigation.navigate('BudgetForm')}
        accessibilityRole="button"
        accessibilityLabel={t('budgets.add')}
        style={[
          styles.fab,
          theme.shadows.raised,
          {
            backgroundColor: theme.colors.primary,
            bottom: insets.bottom + theme.spacing.md,
            right: theme.spacing.md,
          },
        ]}
      >
        <Icon name="add" size={28} color={theme.colors.onPrimary} />
      </Pressable>
    </Screen>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  cardHeader: { flexDirection: 'row', alignItems: 'flex-start' },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  activeDot: { width: 8, height: 8, borderRadius: 4 },
  archiveRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  footerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  amounts: { flexDirection: 'row', alignItems: 'center' },
  fab: {
    position: 'absolute',
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
