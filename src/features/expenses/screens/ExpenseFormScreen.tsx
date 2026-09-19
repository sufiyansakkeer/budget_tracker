import { useEffect, useState } from 'react';
import { zodResolver } from '@hookform/resolvers/zod';
import {
  useNavigation,
  useRoute,
  type RouteProp,
} from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Controller, useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import { AppText } from '../../../components/AppText';
import { Button } from '../../../components/Button';
import { DateTimePickerModal } from '../../../components/DateTimePickerModal';
import { Icon } from '../../../components/Icon';
import { Screen } from '../../../components/Screen';
import { TextField } from '../../../components/TextField';
import { currencyByCode, parseMoney } from '../../../domain/currency';
import { formatDate, formatTime } from '../../../domain/dates';
import type { RootStackParamList } from '../../../navigation/types';
import { useAppSelector } from '../../../store/hooks';
import {
  selectActiveBudgetId,
  selectCurrencyCode,
} from '../../../store/slices/settingsSlice';
import { useTheme } from '../../../theme/ThemeProvider';
import { useBudgets } from '../../budget/hooks/useBudgets';
import { CategoryPicker } from '../components/CategoryPicker';
import { TagInput } from '../components/TagInput';
import {
  useCategories,
  useCreateExpense,
  useExpense,
  useUpdateExpense,
} from '../hooks/useExpenses';
import { expenseSchema, type ExpenseFormValues } from '../validation';

type Navigation = NativeStackNavigationProp<RootStackParamList>;
type FormRoute = RouteProp<RootStackParamList, 'ExpenseForm'>;

export function ExpenseFormScreen() {
  const theme = useTheme();
  const { t } = useTranslation();
  const navigation = useNavigation<Navigation>();
  const route = useRoute<FormRoute>();
  const expenseId = route.params?.expenseId;
  const isEditing = Boolean(expenseId);

  const activeBudgetId = useAppSelector(selectActiveBudgetId);
  const fallbackCurrency = useAppSelector(selectCurrencyCode);

  const { data: categories = [] } = useCategories();
  const { data: budgets = [] } = useBudgets();
  const { data: existing, isPending: isLoadingExpense } = useExpense(expenseId);

  const createExpense = useCreateExpense();
  const updateExpense = useUpdateExpense();
  const [picker, setPicker] = useState(false);

  const {
    control,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<ExpenseFormValues>({
    resolver: zodResolver(expenseSchema(t)),
    defaultValues: {
      amount: '',
      categoryId: '',
      budgetId: route.params?.budgetId ?? activeBudgetId ?? '',
      note: '',
      date: new Date(),
      tags: [],
    },
  });

  const selectedBudgetId = watch('budgetId');
  const selectedDate = watch('date');
  const budget = budgets.find(item => item.id === selectedBudgetId);
  const currencyCode = budget?.currency ?? fallbackCurrency;

  // Populate the form once the record being edited arrives.
  useEffect(() => {
    if (existing) {
      reset({
        amount: String(existing.amount),
        categoryId: existing.categoryId,
        budgetId: existing.budgetId,
        note: existing.note ?? '',
        date: existing.date,
        tags: existing.tags,
      });
    }
  }, [existing, reset]);

  // Default to the first available budget when nothing was passed in and the
  // user has no active budget selected.
  useEffect(() => {
    if (!selectedBudgetId && budgets.length > 0) {
      setValue('budgetId', budgets[0].id);
    }
  }, [budgets, selectedBudgetId, setValue]);

  useEffect(() => {
    navigation.setOptions({
      title: isEditing ? t('expenses.edit') : t('expenses.add'),
    });
  }, [navigation, isEditing, t]);

  const onSubmit = async (values: ExpenseFormValues) => {
    const amount = parseMoney(values.amount);
    if (amount === null) return;

    const payload = {
      categoryId: values.categoryId,
      amount,
      note: values.note.trim() || null,
      date: values.date,
      tags: values.tags,
    };

    if (isEditing && expenseId) {
      await updateExpense.mutateAsync({ id: expenseId, input: payload });
    } else {
      await createExpense.mutateAsync({ ...payload, budgetId: values.budgetId });
    }

    navigation.goBack();
  };

  if (isEditing && isLoadingExpense) {
    return (
      <Screen>
        <View style={styles.centered}>
          <ActivityIndicator color={theme.colors.primary} />
        </View>
      </Screen>
    );
  }

  return (
    <Screen edgeTop={false}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.flex}
      >
        <ScrollView
          contentContainerStyle={{ padding: theme.spacing.md }}
          keyboardShouldPersistTaps="handled"
        >
          <Controller
            control={control}
            name="amount"
            render={({ field }) => (
              <TextField
                label={t('expenses.amount')}
                value={field.value}
                onChangeText={field.onChange}
                onBlur={field.onBlur}
                placeholder="0"
                keyboardType="decimal-pad"
                autoFocus={!isEditing}
                prefix={currencyByCode(currencyCode).symbol}
                error={errors.amount?.message}
              />
            )}
          />

          <View style={{ marginTop: theme.spacing.lg }}>
            <AppText variant="label" color="textSecondary">
              {t('expenses.category')}
            </AppText>
            <Controller
              control={control}
              name="categoryId"
              render={({ field }) => (
                <CategoryPicker
                  categories={categories}
                  selectedId={field.value}
                  onSelect={field.onChange}
                />
              )}
            />
            {errors.categoryId ? (
              <AppText variant="caption" color="error">
                {errors.categoryId.message}
              </AppText>
            ) : null}
          </View>

          <Pressable
            onPress={() => setPicker(true)}
            accessibilityRole="button"
            style={[
              styles.dateRow,
              {
                borderColor: theme.colors.outline,
                borderRadius: theme.radius.sm,
                padding: theme.spacing.smd,
                marginTop: theme.spacing.lg,
              },
            ]}
          >
            <View style={styles.flex}>
              <AppText variant="label" color="textSecondary">
                {t('expenses.date')}
              </AppText>
              <AppText variant="subtitle" style={{ marginTop: theme.spacing.xs }}>
                {formatDate(selectedDate)} · {formatTime(selectedDate)}
              </AppText>
            </View>
            <Icon name="event" size={20} color="textSecondary" />
          </Pressable>
          {errors.date ? (
            <AppText variant="caption" color="error">
              {errors.date.message}
            </AppText>
          ) : null}

          <Controller
            control={control}
            name="note"
            render={({ field }) => (
              <TextField
                label={t('expenses.note')}
                value={field.value}
                onChangeText={field.onChange}
                onBlur={field.onBlur}
                placeholder={t('expenses.notePlaceholder')}
                multiline
                maxLength={280}
                error={errors.note?.message}
                containerStyle={{ marginTop: theme.spacing.lg }}
              />
            )}
          />

          <View style={{ marginTop: theme.spacing.lg }}>
            <Controller
              control={control}
              name="tags"
              render={({ field }) => (
                <TagInput
                  label={t('expenses.tags')}
                  placeholder={t('expenses.tagsPlaceholder')}
                  tags={field.value}
                  onChange={field.onChange}
                />
              )}
            />
          </View>

          {/* The budget cannot change on an existing expense — moving a spend
              between budgets would silently rewrite two sets of totals. */}
          {!isEditing && budgets.length > 1 ? (
            <View style={{ marginTop: theme.spacing.lg }}>
              <AppText variant="label" color="textSecondary">
                {t('expenses.budget')}
              </AppText>
              <Controller
                control={control}
                name="budgetId"
                render={({ field }) => (
                  <View style={{ marginTop: theme.spacing.sm }}>
                    {budgets.map(item => {
                      const selected = item.id === field.value;
                      return (
                        <Pressable
                          key={item.id}
                          onPress={() => field.onChange(item.id)}
                          accessibilityRole="radio"
                          accessibilityState={{ selected }}
                          style={[
                            styles.budgetRow,
                            {
                              borderColor: selected
                                ? theme.colors.primary
                                : theme.colors.divider,
                              borderRadius: theme.radius.sm,
                              padding: theme.spacing.smd,
                              marginBottom: theme.spacing.sm,
                            },
                          ]}
                        >
                          <AppText variant="subtitle" style={styles.flex}>
                            {item.name}
                          </AppText>
                          {selected ? (
                            <Icon name="check" size={18} color="primary" />
                          ) : null}
                        </Pressable>
                      );
                    })}
                  </View>
                )}
              />
              {errors.budgetId ? (
                <AppText variant="caption" color="error">
                  {errors.budgetId.message}
                </AppText>
              ) : null}
            </View>
          ) : null}

          <Button
            label={t('common.save')}
            onPress={handleSubmit(onSubmit)}
            loading={isSubmitting}
            style={{ marginTop: theme.spacing.xl }}
          />
        </ScrollView>
      </KeyboardAvoidingView>

      <Controller
        control={control}
        name="date"
        render={({ field }) => (
          <DateTimePickerModal
            visible={picker}
            value={field.value}
            title={t('expenses.date')}
            withTime
            maximumDate={new Date()}
            onConfirm={date => {
              field.onChange(date);
              setPicker(false);
            }}
            onCancel={() => setPicker(false)}
            confirmLabel={t('common.done')}
            cancelLabel={t('common.cancel')}
          />
        )}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: StyleSheet.hairlineWidth,
  },
  budgetRow: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: StyleSheet.hairlineWidth,
  },
});
