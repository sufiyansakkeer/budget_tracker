import { useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import { useTranslation } from 'react-i18next';
import { AppText } from '../../../components/AppText';
import { Button } from '../../../components/Button';
import { Card } from '../../../components/Card';
import { DateTimePickerModal } from '../../../components/DateTimePickerModal';
import { Icon } from '../../../components/Icon';
import { Screen } from '../../../components/Screen';
import { TextField } from '../../../components/TextField';
import {
  availableCurrencies,
  currencyByCode,
  formatMoney,
  parseMoney,
} from '../../../domain/currency';
import { formatDate, monthBounds } from '../../../domain/dates';
import { useAppDispatch } from '../../../store/hooks';
import {
  setActiveBudgetId,
  setCurrencyCode,
  setOnboardingCompleted,
} from '../../../store/slices/settingsSlice';
import { useTheme } from '../../../theme/ThemeProvider';
import { useCreateBudget } from '../../budget/hooks/useBudgets';

type Step = 'welcome' | 'currency' | 'name' | 'amount' | 'dates' | 'confirm';

const STEPS: Step[] = ['welcome', 'currency', 'name', 'amount', 'dates', 'confirm'];

/**
 * First-launch wizard: pick a currency, then create the first budget.
 *
 * The whole flow is one screen with a step cursor rather than a nested
 * navigator — there is nothing to deep-link to and no reason for these steps
 * to survive in the back stack once the budget exists.
 */
export function OnboardingScreen() {
  const theme = useTheme();
  const { t } = useTranslation();
  const dispatch = useAppDispatch();
  const createBudget = useCreateBudget();

  const [stepIndex, setStepIndex] = useState(0);
  const step = STEPS[stepIndex];

  const defaultRange = monthBounds(new Date());
  const [currency, setCurrency] = useState('INR');
  const [name, setName] = useState('');
  const [amountText, setAmountText] = useState('');
  const [startDate, setStartDate] = useState(defaultRange.start);
  const [endDate, setEndDate] = useState(defaultRange.end);
  const [picker, setPicker] = useState<'start' | 'end' | null>(null);
  const [error, setError] = useState<string | null>(null);

  const amount = parseMoney(amountText);
  const trimmedName = name.trim();

  /** Returns null when the current step is satisfied, or the message to show. */
  const validateStep = (): string | null => {
    if (step === 'name' && trimmedName.length === 0) {
      return t('budgets.validation.nameRequired');
    }
    if (step === 'amount') {
      if (amount === null) return t('budgets.validation.amountRequired');
      if (amount <= 0) return t('budgets.validation.amountPositive');
    }
    if (step === 'dates' && endDate < startDate) {
      return t('budgets.validation.endBeforeStart');
    }
    return null;
  };

  const goNext = () => {
    const message = validateStep();
    if (message) {
      setError(message);
      return;
    }
    setError(null);
    setStepIndex(index => Math.min(index + 1, STEPS.length - 1));
  };

  const goBack = () => {
    setError(null);
    setStepIndex(index => Math.max(index - 1, 0));
  };

  const finish = async () => {
    if (amount === null) return;

    const budget = await createBudget.mutateAsync({
      name: trimmedName,
      amount,
      currency,
      startDate,
      endDate,
    });

    // Order matters: the budget must exist and be selected before the root
    // navigator swaps onboarding out for the dashboard.
    dispatch(setCurrencyCode(currency));
    dispatch(setActiveBudgetId(budget.id));
    dispatch(setOnboardingCompleted(true));
  };

  return (
    <Screen padded>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.flex}
      >
        <View style={[styles.progress, { marginTop: theme.spacing.md }]}>
          {STEPS.map((item, index) => (
            <View
              key={item}
              style={[
                styles.progressDot,
                {
                  backgroundColor:
                    index <= stepIndex
                      ? theme.colors.primary
                      : theme.colors.surfaceContainerHigh,
                },
              ]}
            />
          ))}
        </View>

        <ScrollView
          contentContainerStyle={[
            styles.content,
            { paddingVertical: theme.spacing.lg },
          ]}
          keyboardShouldPersistTaps="handled"
        >
          {step === 'welcome' ? (
            <StepBody
              icon="savings"
              title={t('onboarding.welcomeTitle')}
              body={t('onboarding.welcomeBody')}
            />
          ) : null}

          {step === 'currency' ? (
            <>
              <StepBody
                icon="payments"
                title={t('onboarding.currencyTitle')}
                body={t('onboarding.currencyBody')}
              />
              <View style={{ marginTop: theme.spacing.lg }}>
                {availableCurrencies.map(item => {
                  const selected = item.code === currency;
                  return (
                    <Pressable
                      key={item.code}
                      onPress={() => setCurrency(item.code)}
                      accessibilityRole="radio"
                      accessibilityState={{ selected }}
                      style={[
                        styles.currencyRow,
                        {
                          borderColor: selected
                            ? theme.colors.primary
                            : theme.colors.divider,
                          backgroundColor: selected
                            ? theme.colors.primaryContainer
                            : theme.colors.surface,
                          borderRadius: theme.radius.sm,
                          padding: theme.spacing.smd,
                          marginBottom: theme.spacing.sm,
                        },
                      ]}
                    >
                      <AppText variant="subtitle" style={styles.currencySymbol}>
                        {item.symbol}
                      </AppText>
                      <View style={styles.flex}>
                        <AppText variant="subtitle">{item.name}</AppText>
                        <AppText variant="caption" color="textSecondary">
                          {item.code}
                        </AppText>
                      </View>
                      {selected ? (
                        <Icon name="check-circle" size={20} color="primary" />
                      ) : null}
                    </Pressable>
                  );
                })}
              </View>
            </>
          ) : null}

          {step === 'name' ? (
            <>
              <StepBody
                icon="edit"
                title={t('onboarding.nameTitle')}
                body={t('onboarding.nameBody')}
              />
              <TextField
                value={name}
                onChangeText={setName}
                placeholder={t('onboarding.namePlaceholder')}
                autoFocus
                maxLength={100}
                error={error ?? undefined}
                containerStyle={{ marginTop: theme.spacing.lg }}
              />
            </>
          ) : null}

          {step === 'amount' ? (
            <>
              <StepBody
                icon="account-balance-wallet"
                title={t('onboarding.amountTitle')}
                body={t('onboarding.amountBody')}
              />
              <TextField
                value={amountText}
                onChangeText={setAmountText}
                placeholder="0"
                keyboardType="decimal-pad"
                autoFocus
                prefix={currencyByCode(currency).symbol}
                error={error ?? undefined}
                containerStyle={{ marginTop: theme.spacing.lg }}
              />
            </>
          ) : null}

          {step === 'dates' ? (
            <>
              <StepBody
                icon="date-range"
                title={t('onboarding.datesTitle')}
                body={t('onboarding.datesBody')}
              />
              <View style={{ marginTop: theme.spacing.lg }}>
                <DateRow
                  label={t('onboarding.startDate')}
                  value={formatDate(startDate)}
                  onPress={() => setPicker('start')}
                />
                <DateRow
                  label={t('onboarding.endDate')}
                  value={formatDate(endDate)}
                  onPress={() => setPicker('end')}
                />
                {error ? (
                  <AppText variant="caption" color="error">
                    {error}
                  </AppText>
                ) : null}
              </View>
            </>
          ) : null}

          {step === 'confirm' ? (
            <>
              <StepBody
                icon="check-circle"
                title={t('onboarding.confirmTitle')}
                body={t('onboarding.confirmBody')}
              />
              <Card style={{ marginTop: theme.spacing.lg }}>
                <SummaryRow label={t('budgets.name')} value={trimmedName} />
                <SummaryRow
                  label={t('budgets.amount')}
                  value={formatMoney(amount ?? 0, currency)}
                />
                <SummaryRow
                  label={t('budgets.currency')}
                  value={currencyByCode(currency).name}
                />
                <SummaryRow
                  label={t('budgets.startDate')}
                  value={formatDate(startDate)}
                />
                <SummaryRow
                  label={t('budgets.endDate')}
                  value={formatDate(endDate)}
                />
              </Card>
            </>
          ) : null}
        </ScrollView>

        <View style={[styles.footer, { paddingBottom: theme.spacing.lg }]}>
          {stepIndex > 0 ? (
            <Button
              label={t('common.back')}
              variant="ghost"
              onPress={goBack}
              style={styles.flex}
            />
          ) : null}
          <Button
            label={
              step === 'welcome'
                ? t('onboarding.getStarted')
                : step === 'confirm'
                  ? t('onboarding.createBudget')
                  : t('common.next')
            }
            onPress={step === 'confirm' ? finish : goNext}
            loading={createBudget.isPending}
            style={styles.flex}
          />
        </View>
      </KeyboardAvoidingView>

      <DateTimePickerModal
        visible={picker !== null}
        value={picker === 'end' ? endDate : startDate}
        title={picker === 'end' ? t('onboarding.endDate') : t('onboarding.startDate')}
        minimumDate={picker === 'end' ? startDate : undefined}
        onConfirm={date => {
          if (picker === 'end') {
            setEndDate(date);
          } else {
            setStartDate(date);
            // Keep the range valid rather than letting the user walk away with
            // an end date that now precedes the start.
            if (endDate < date) setEndDate(date);
          }
          setPicker(null);
          setError(null);
        }}
        onCancel={() => setPicker(null)}
        confirmLabel={t('common.done')}
        cancelLabel={t('common.cancel')}
      />
    </Screen>
  );
}

function StepBody({
  icon,
  title,
  body,
}: {
  icon: string;
  title: string;
  body: string;
}) {
  const theme = useTheme();
  return (
    <View style={styles.stepBody}>
      <View
        style={[
          styles.stepIcon,
          { backgroundColor: theme.colors.primaryContainer },
        ]}
      >
        <Icon name={icon} size={36} color="primary" />
      </View>
      <AppText
        variant="displaySmall"
        align="center"
        style={{ marginTop: theme.spacing.lg }}
      >
        {title}
      </AppText>
      <AppText
        variant="body"
        color="textSecondary"
        align="center"
        style={{ marginTop: theme.spacing.sm }}
      >
        {body}
      </AppText>
    </View>
  );
}

function DateRow({
  label,
  value,
  onPress,
}: {
  label: string;
  value: string;
  onPress: () => void;
}) {
  const theme = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={`${label}: ${value}`}
      style={[
        styles.dateRow,
        {
          borderColor: theme.colors.outline,
          borderRadius: theme.radius.sm,
          padding: theme.spacing.smd,
          marginBottom: theme.spacing.sm,
        },
      ]}
    >
      <AppText variant="label" color="textSecondary">
        {label}
      </AppText>
      <View style={styles.dateValue}>
        <AppText variant="subtitle">{value}</AppText>
        <Icon name="calendar-today" size={18} color="textSecondary" />
      </View>
    </Pressable>
  );
}

function SummaryRow({ label, value }: { label: string; value: string }) {
  const theme = useTheme();
  return (
    <View style={[styles.summaryRow, { paddingVertical: theme.spacing.sm }]}>
      <AppText variant="body" color="textSecondary">
        {label}
      </AppText>
      <AppText variant="subtitle">{value}</AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  progress: { flexDirection: 'row', gap: 6 },
  progressDot: { flex: 1, height: 4, borderRadius: 2 },
  content: { flexGrow: 1, justifyContent: 'center' },
  stepBody: { alignItems: 'center' },
  stepIcon: {
    width: 88,
    height: 88,
    borderRadius: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  currencyRow: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    gap: 12,
  },
  currencySymbol: { width: 32, textAlign: 'center' },
  dateRow: { borderWidth: StyleSheet.hairlineWidth },
  dateValue: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  summaryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  footer: { flexDirection: 'row', gap: 12 },
});
