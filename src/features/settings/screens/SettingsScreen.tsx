import { useTranslation } from 'react-i18next';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { version as appVersion } from '../../../../package.json';
import { AppText } from '../../../components/AppText';
import { Card } from '../../../components/Card';
import { Chip } from '../../../components/Chip';
import { confirm } from '../../../components/ConfirmDialog';
import { Icon } from '../../../components/Icon';
import { Screen } from '../../../components/Screen';
import { SectionHeader } from '../../../components/SectionHeader';
import { availableCurrencies, currencyByCode } from '../../../domain/currency';
import type { RootStackParamList } from '../../../navigation/types';
import { useAppDispatch, useAppSelector } from '../../../store/hooks';
import {
  selectActiveBudgetId,
  selectCurrencyCode,
  selectThemeMode,
  setCurrencyCode,
  setOnboardingCompleted,
  setThemeMode,
} from '../../../store/slices/settingsSlice';
import type { ThemeMode } from '../../../theme/theme';
import { useTheme } from '../../../theme/ThemeProvider';
import { useBudgets } from '../../budget/hooks/useBudgets';

type Navigation = NativeStackNavigationProp<RootStackParamList>;

const THEME_MODES: { mode: ThemeMode; labelKey: string; icon: string }[] = [
  { mode: 'light', labelKey: 'settings.themeLight', icon: 'light-mode' },
  { mode: 'dark', labelKey: 'settings.themeDark', icon: 'dark-mode' },
  { mode: 'system', labelKey: 'settings.themeSystem', icon: 'brightness-auto' },
];

export function SettingsScreen() {
  const theme = useTheme();
  const { t } = useTranslation();
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<Navigation>();
  const dispatch = useAppDispatch();

  const themeMode = useAppSelector(selectThemeMode);
  const currencyCode = useAppSelector(selectCurrencyCode);
  const activeBudgetId = useAppSelector(selectActiveBudgetId);

  const { data: budgets = [] } = useBudgets();
  const activeBudget = budgets.find(budget => budget.id === activeBudgetId);

  const replayOnboarding = async () => {
    const confirmed = await confirm({
      title: t('settings.resetOnboarding'),
      message: t('settings.resetOnboardingBody'),
      confirmLabel: t('common.confirm'),
      cancelLabel: t('common.cancel'),
    });
    if (confirmed) {
      dispatch(setOnboardingCompleted(false));
    }
  };

  return (
    <Screen>
      <ScrollView
        contentContainerStyle={{
          padding: theme.spacing.md,
          paddingBottom: insets.bottom + theme.spacing.xl,
        }}
      >
        <AppText variant="headline" style={{ marginBottom: theme.spacing.md }}>
          {t('settings.title')}
        </AppText>

        <SectionHeader title={t('settings.appearance')} />
        <Card>
          <AppText variant="label" color="textSecondary">
            {t('settings.theme')}
          </AppText>
          <View style={[styles.chipRow, { marginTop: theme.spacing.sm }]}>
            {THEME_MODES.map(item => (
              <Chip
                key={item.mode}
                label={t(item.labelKey)}
                icon={item.icon}
                selected={themeMode === item.mode}
                onPress={() => dispatch(setThemeMode(item.mode))}
              />
            ))}
          </View>
        </Card>

        <View style={{ marginTop: theme.spacing.lg }}>
          <SectionHeader title={t('settings.money')} />
          <Card>
            <AppText variant="label" color="textSecondary">
              {t('settings.currency')}
            </AppText>
            <AppText variant="caption" color="textTertiary">
              {currencyByCode(currencyCode).name}
            </AppText>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={[styles.chipRow, { marginTop: theme.spacing.sm }]}
            >
              {availableCurrencies.map(item => (
                <Chip
                  key={item.code}
                  label={`${item.symbol} ${item.code}`}
                  selected={item.code === currencyCode}
                  onPress={() => dispatch(setCurrencyCode(item.code))}
                />
              ))}
            </ScrollView>
          </Card>
        </View>

        <View style={{ marginTop: theme.spacing.lg }}>
          <SectionHeader title={t('settings.data')} />
          <Card padded={false}>
            <SettingsRow
              icon="account-balance-wallet"
              label={t('settings.activeBudget')}
              value={activeBudget?.name ?? t('settings.noActiveBudget')}
              onPress={() => navigation.navigate('Main', { screen: 'Budgets' })}
            />
            <SettingsRow
              icon="replay"
              label={t('settings.resetOnboarding')}
              onPress={replayOnboarding}
              isLast
            />
          </Card>
        </View>

        <View style={{ marginTop: theme.spacing.lg }}>
          <SectionHeader title={t('settings.about')} />
          <Card>
            <View style={styles.aboutRow}>
              <AppText variant="body" color="textSecondary">
                {t('settings.version')}
              </AppText>
              <AppText variant="subtitle">{appVersion}</AppText>
            </View>
          </Card>
        </View>
      </ScrollView>
    </Screen>
  );
}

function SettingsRow({
  icon,
  label,
  value,
  onPress,
  isLast = false,
}: {
  icon: string;
  label: string;
  value?: string;
  onPress: () => void;
  isLast?: boolean;
}) {
  const theme = useTheme();

  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={value ? `${label}: ${value}` : label}
      style={({ pressed }) => [
        styles.settingsRow,
        {
          padding: theme.spacing.md,
          borderBottomWidth: isLast ? 0 : StyleSheet.hairlineWidth,
          borderBottomColor: theme.colors.divider,
          opacity: pressed ? 0.7 : 1,
        },
      ]}
    >
      <Icon name={icon} size={20} color="textSecondary" />
      <View style={[styles.flex, { marginHorizontal: theme.spacing.smd }]}>
        <AppText variant="body">{label}</AppText>
        {value ? (
          <AppText variant="caption" color="textTertiary">
            {value}
          </AppText>
        ) : null}
      </View>
      <Icon name="chevron-right" size={20} color="textTertiary" />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  chipRow: { flexDirection: 'row', gap: 8, paddingRight: 16 },
  settingsRow: { flexDirection: 'row', alignItems: 'center' },
  aboutRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
});
