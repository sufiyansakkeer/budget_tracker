import { useMemo, useState } from 'react';
import {
  useNavigation,
  useRoute,
  type RouteProp,
} from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useTranslation } from 'react-i18next';
import {
  ActivityIndicator,
  Pressable,
  RefreshControl,
  ScrollView,
  SectionList,
  StyleSheet,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '../../../components/AppText';
import { Card } from '../../../components/Card';
import { Chip } from '../../../components/Chip';
import { EmptyState } from '../../../components/EmptyState';
import { Icon } from '../../../components/Icon';
import { MoneyText } from '../../../components/MoneyText';
import { Screen } from '../../../components/Screen';
import { TextField } from '../../../components/TextField';
import { categoryById } from '../../../domain/categories';
import { formatRelativeDay } from '../../../domain/dates';
import type { Expense, ExpenseSortOrder } from '../../../domain/types';
import type { MainTabParamList, RootStackParamList } from '../../../navigation/types';
import { useAppSelector } from '../../../store/hooks';
import { selectActiveBudgetId } from '../../../store/slices/settingsSlice';
import { useTheme } from '../../../theme/ThemeProvider';
import { ExpenseRow } from '../../dashboard/components/ExpenseRow';
import { groupByDay } from '../../../domain/expenses';
import { useCategories, useExpenses } from '../hooks/useExpenses';

type Navigation = NativeStackNavigationProp<RootStackParamList>;
type HistoryRoute = RouteProp<MainTabParamList, 'Expenses'>;

const SORT_ORDERS: ExpenseSortOrder[] = [
  'date_desc',
  'date_asc',
  'amount_desc',
  'amount_asc',
];

export function ExpenseHistoryScreen() {
  const theme = useTheme();
  const { t } = useTranslation();
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<Navigation>();
  const route = useRoute<HistoryRoute>();
  const activeBudgetId = useAppSelector(selectActiveBudgetId);
  const budgetId = route.params?.budgetId ?? activeBudgetId ?? undefined;

  const [search, setSearch] = useState('');
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [order, setOrder] = useState<ExpenseSortOrder>('date_desc');

  const { data: categories = [] } = useCategories();

  // The filter object is part of the query key, so it must be referentially
  // stable — an inline object would make every render a cache miss.
  const filter = useMemo(
    () => ({
      budgetId,
      search: search.trim() || undefined,
      categoryIds: selectedCategories.length > 0 ? selectedCategories : undefined,
    }),
    [budgetId, search, selectedCategories],
  );

  const { data: expenses = [], isPending, isRefetching, refetch } = useExpenses(
    filter,
    order,
  );

  const sections = useMemo(
    () =>
      groupByDay(expenses).map(group => ({
        title: formatRelativeDay(group.date),
        total: group.total,
        data: group.expenses,
      })),
    [expenses],
  );

  const total = useMemo(
    () => expenses.reduce((sum, expense) => sum + expense.amount, 0),
    [expenses],
  );

  const toggleCategory = (categoryId: string) => {
    setSelectedCategories(current =>
      current.includes(categoryId)
        ? current.filter(id => id !== categoryId)
        : [...current, categoryId],
    );
  };

  const cycleSort = () => {
    const index = SORT_ORDERS.indexOf(order);
    setOrder(SORT_ORDERS[(index + 1) % SORT_ORDERS.length]);
  };

  const hasFilters = search.trim().length > 0 || selectedCategories.length > 0;

  const renderItem = ({ item }: { item: Expense }) => (
    <Pressable
      onPress={() => navigation.navigate('ExpenseDetails', { expenseId: item.id })}
      accessibilityRole="button"
      style={{ paddingHorizontal: theme.spacing.md }}
    >
      <ExpenseRow
        expense={item}
        category={categoryById(categories, item.categoryId)}
      />
    </Pressable>
  );

  return (
    <Screen>
      <View style={{ padding: theme.spacing.md, paddingBottom: theme.spacing.sm }}>
        <View style={styles.headerRow}>
          <AppText variant="headline" style={styles.flex}>
            {t('expenses.title')}
          </AppText>
          <Pressable
            onPress={cycleSort}
            hitSlop={8}
            accessibilityRole="button"
            accessibilityLabel={t(`expenses.sort.${order}`)}
            style={styles.sortButton}
          >
            <Icon name="swap-vert" size={20} color="primary" />
            <AppText variant="label" color="primary">
              {t(`expenses.sort.${order}`)}
            </AppText>
          </Pressable>
        </View>

        <TextField
          value={search}
          onChangeText={setSearch}
          placeholder={t('expenses.searchPlaceholder')}
          autoCorrect={false}
          containerStyle={{ marginTop: theme.spacing.smd }}
        />

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={[styles.chipRow, { marginTop: theme.spacing.smd }]}
        >
          <Chip
            label={t('common.all')}
            selected={selectedCategories.length === 0}
            onPress={() => setSelectedCategories([])}
          />
          {categories.map(category => (
            <Chip
              key={category.id}
              label={category.name}
              icon={category.icon}
              selected={selectedCategories.includes(category.id)}
              onPress={() => toggleCategory(category.id)}
              tintColor={category.colorHex}
            />
          ))}
        </ScrollView>

        {expenses.length > 0 ? (
          <Card style={{ marginTop: theme.spacing.smd }}>
            <View style={styles.summaryRow}>
              <View>
                <AppText variant="caption" color="textSecondary">
                  {t('expenses.total')}
                </AppText>
                <MoneyText amount={total} variant="title" />
              </View>
              <AppText variant="caption" color="textTertiary">
                {t('expenses.count', { count: expenses.length })}
              </AppText>
            </View>
          </Card>
        ) : null}
      </View>

      {isPending ? (
        <View style={styles.centered}>
          <ActivityIndicator color={theme.colors.primary} />
        </View>
      ) : (
        <SectionList
          sections={sections}
          keyExtractor={item => item.id}
          renderItem={renderItem}
          stickySectionHeadersEnabled={false}
          contentContainerStyle={{ paddingBottom: insets.bottom + theme.spacing.xl }}
          refreshControl={
            <RefreshControl
              refreshing={isRefetching}
              onRefresh={() => {
                refetch();
              }}
              tintColor={theme.colors.primary}
            />
          }
          renderSectionHeader={({ section }) => (
            <View
              style={[
                styles.sectionHeader,
                {
                  backgroundColor: theme.colors.background,
                  paddingHorizontal: theme.spacing.md,
                  paddingTop: theme.spacing.smd,
                  paddingBottom: theme.spacing.xs,
                },
              ]}
            >
              <AppText variant="label" color="textSecondary">
                {section.title}
              </AppText>
              <MoneyText amount={section.total} variant="label" color="textSecondary" />
            </View>
          )}
          ListEmptyComponent={
            hasFilters ? (
              <EmptyState
                icon="search-off"
                title={t('expenses.noResultsTitle')}
                body={t('expenses.noResultsBody')}
                actionLabel={t('common.clear')}
                onAction={() => {
                  setSearch('');
                  setSelectedCategories([]);
                }}
              />
            ) : (
              <EmptyState
                icon="receipt-long"
                title={t('expenses.emptyTitle')}
                body={t('expenses.emptyBody')}
                actionLabel={t('expenses.add')}
                onAction={() => navigation.navigate('ExpenseForm', { budgetId })}
              />
            )
          }
        />
      )}

      <Pressable
        onPress={() => navigation.navigate('ExpenseForm', { budgetId })}
        accessibilityRole="button"
        accessibilityLabel={t('expenses.add')}
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
  headerRow: { flexDirection: 'row', alignItems: 'center' },
  sortButton: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  chipRow: { gap: 8, paddingRight: 16 },
  summaryRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  fab: {
    position: 'absolute',
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
