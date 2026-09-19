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
import { Chip } from '../../../components/Chip';
import { DateTimePickerModal } from '../../../components/DateTimePickerModal';
import { Icon } from '../../../components/Icon';
import { Screen } from '../../../components/Screen';
import { TextField } from '../../../components/TextField';
import {
  availableCurrencies,
  currencyByCode,
  parseMoney,
} from '../../../domain/currency';
import { formatDate, monthBounds } from '../../../domain/dates';
import type { RootStackParamList } from '../../../navigation/types';
import { useAppDispatch, useAppSelector } from '../../../store/hooks';
import {
  selectActiveBudgetId,
  selectCurrencyCode,
  setActiveBudgetId,
} from '../../../store/slices/settingsSlice';
import { useTheme } from '../../../theme/ThemeProvider';
import { budgetSchema, type BudgetFormValues } from '../validation';
import { useBudget, useCreateBudget, useUpdateBudget } from '../hooks/useBudgets';

type Navigation = NativeStackNavigationProp<RootStackParamList>;
type FormRoute = RouteProp<RootStackParamList, 'BudgetForm'>;

export function BudgetFormScreen() {
  const theme = useTheme();
  const { t } = useTranslation();
  const navigation = useNavigation<Navigation>();
  const route = useRoute<FormRoute>();
  const budgetId = route.params?.budgetId;
  const isEditing = Boolean(budgetId);

  const dispatch = useAppDispatch();
  const activeBudgetId = useAppSelector(selectActiveBudgetId);
  const defaultCurrency = useAppSelector(selectCurrencyCode);

  const { data: existing, isPending: isLoadingBudget } = useBudget(budgetId);
  const createBudget = useCreateBudget();
  const updateBudget = useUpdateBudget();
  const [picker, setPicker] = useState<'start' | 'end' | null>(null);

  const defaultRange = monthBounds(new Date());

  const {
    control,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<BudgetFormValues>({
    resolver: zodResolver(budgetSchema(t)),
    defaultValues: {
      name: '',
      amount: '',
      currency: defaultCurrency,
      startDate: defaultRange.start,
      endDate: defaultRange.end,
      notes: '',
    },
  });

  const startDate = watch('startDate');
  const endDate = watch('endDate');
  const currency = watch('currency');

  useEffect(() => {
    if (existing) {
      reset({
        name: existing.name,
        amount: String(existing.amount),
        currency: existing.currency,
        startDate: existing.startDate,
        endDate: existing.endDate,
        notes: existing.notes ?? '',
      });
    }
  }, [existing, reset]);

  useEffect(() => {
    navigation.setOptions({
      title: isEditing ? t('budgets.edit') : t('budgets.add'),
    });
  }, [navigation, isEditing, t]);

  const onSubmit = async (values: BudgetFormValues) => {
    const amount = parseMoney(values.amount);
    if (amount === null) return;

    const payload = {
      name: values.name.trim(),
      amount,
      currency: values.currency,
      startDate: values.startDate,
      endDate: values.endDate,
      notes: values.notes.trim() || null,
    };

    if (isEditing && budgetId) {
      await updateBudget.mutateAsync({ id: budgetId, input: payload });
    } else {
      const created = await createBudget.mutateAsync(payload);
      // A first budget is useless until something points at it, so adopt it
      // when the user has no active selection.
      if (!activeBudgetId) {
        dispatch(setActiveBudgetId(created.id));
      }
    }

    navigation.goBack();
  };

  if (isEditing && isLoadingBudget) {
    return (
      <Screen edgeTop={false}>
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
            name="name"
            render={({ field }) => (
              <TextField
                label={t('budgets.name')}
                value={field.value}
                onChangeText={field.onChange}
                onBlur={field.onBlur}
                placeholder={t('budgets.namePlaceholder')}
                maxLength={100}
                error={errors.name?.message}
              />
            )}
          />

          <Controller
            control={control}
            name="amount"
            render={({ field }) => (
              <TextField
                label={t('budgets.amount')}
                value={field.value}
                onChangeText={field.onChange}
                onBlur={field.onBlur}
                placeholder="0"
                keyboardType="decimal-pad"
                prefix={currencyByCode(currency).symbol}
                error={errors.amount?.message}
                containerStyle={{ marginTop: theme.spacing.lg }}
              />
            )}
          />

          <View style={{ marginTop: theme.spacing.lg }}>
            <AppText variant="label" color="textSecondary">
              {t('budgets.currency')}
            </AppText>
            <Controller
              control={control}
              name="currency"
              render={({ field }) => (
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={[
                    styles.chipRow,
                    { marginTop: theme.spacing.sm },
                  ]}
                >
                  {availableCurrencies.map(item => (
                    <Chip
                      key={item.code}
                      label={`${item.symbol} ${item.code}`}
                      selected={item.code === field.value}
                      onPress={() => field.onChange(item.code)}
                    />
                  ))}
                </ScrollView>
              )}
            />
          </View>

          <View style={[styles.dateRow, { marginTop: theme.spacing.lg }]}>
            <DateField
              label={t('budgets.startDate')}
              value={formatDate(startDate)}
              onPress={() => setPicker('start')}
            />
            <DateField
              label={t('budgets.endDate')}
              value={formatDate(endDate)}
              onPress={() => setPicker('end')}
              error={errors.endDate?.message}
            />
          </View>

          <Controller
            control={control}
            name="notes"
            render={({ field }) => (
              <TextField
                label={t('budgets.notes')}
                value={field.value}
                onChangeText={field.onChange}
                onBlur={field.onBlur}
                placeholder={t('budgets.notesPlaceholder')}
                multiline
                maxLength={280}
                containerStyle={{ marginTop: theme.spacing.lg }}
              />
            )}
          />

          <Button
            label={t('common.save')}
            onPress={handleSubmit(onSubmit)}
            loading={isSubmitting}
            style={{ marginTop: theme.spacing.xl }}
          />
        </ScrollView>
      </KeyboardAvoidingView>

      <DateTimePickerModal
        visible={picker !== null}
        value={picker === 'end' ? endDate : startDate}
        title={picker === 'end' ? t('budgets.endDate') : t('budgets.startDate')}
        minimumDate={picker === 'end' ? startDate : undefined}
        onConfirm={date => {
          if (picker === 'end') {
            setValue('endDate', date, { shouldValidate: true });
          } else {
            setValue('startDate', date, { shouldValidate: true });
            if (endDate < date) {
              setValue('endDate', date, { shouldValidate: true });
            }
          }
          setPicker(null);
        }}
        onCancel={() => setPicker(null)}
        confirmLabel={t('common.done')}
        cancelLabel={t('common.cancel')}
      />
    </Screen>
  );
}

function DateField({
  label,
  value,
  onPress,
  error,
}: {
  label: string;
  value: string;
  onPress: () => void;
  error?: string;
}) {
  const theme = useTheme();
  return (
    <View style={styles.flex}>
      <AppText variant="label" color="textSecondary">
        {label}
      </AppText>
      <Pressable
        onPress={onPress}
        accessibilityRole="button"
        accessibilityLabel={`${label}: ${value}`}
        style={[
          styles.dateField,
          {
            borderColor: error ? theme.colors.error : theme.colors.outline,
            borderRadius: theme.radius.sm,
            padding: theme.spacing.smd,
            marginTop: theme.spacing.xs,
          },
        ]}
      >
        <AppText variant="body">{value}</AppText>
        <Icon name="event" size={18} color="textSecondary" />
      </Pressable>
      {error ? (
        <AppText variant="caption" color="error" style={styles.fieldError}>
          {error}
        </AppText>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  chipRow: { gap: 8, paddingRight: 16 },
  fieldError: { marginTop: 4 },
  dateRow: { flexDirection: 'row', gap: 12 },
  dateField: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderWidth: StyleSheet.hairlineWidth,
    minHeight: 48,
  },
});
