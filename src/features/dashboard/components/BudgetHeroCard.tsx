import { StyleSheet, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { AppText } from '../../../components/AppText';
import { Card } from '../../../components/Card';
import { MoneyText } from '../../../components/MoneyText';
import { ProgressBar } from '../../../components/ProgressBar';
import type { BudgetSummary } from '../../../domain/budget/calculations';
import type { Budget } from '../../../domain/types';
import type { ColorToken } from '../../../theme/colors';
import { useTheme } from '../../../theme/ThemeProvider';

interface BudgetHeroCardProps {
  budget: Budget;
  summary: BudgetSummary;
}

const STATUS_COLOR: Record<BudgetSummary['status'], ColorToken> = {
  underBudget: 'success',
  nearLimit: 'warning',
  overBudget: 'error',
};

/** The headline card: what is safe to spend today, and how the period stands. */
export function BudgetHeroCard({ budget, summary }: BudgetHeroCardProps) {
  const theme = useTheme();
  const { t } = useTranslation();
  const statusColor = STATUS_COLOR[summary.status];

  return (
    <Card>
      <View style={styles.headerRow}>
        <View style={styles.flex}>
          <AppText variant="label" color="textSecondary">
            {budget.name}
          </AppText>
          <AppText variant="caption" color="textTertiary">
            {t('dashboard.daysLeft', { count: summary.daysRemaining })}
          </AppText>
        </View>
        <View
          style={[
            styles.statusPill,
            {
              backgroundColor: theme.colors[`${statusColor}Container` as ColorToken],
              borderRadius: theme.radius.full,
              paddingHorizontal: theme.spacing.smd,
              paddingVertical: theme.spacing.xs,
            },
          ]}
        >
          <AppText variant="caption" color={statusColor}>
            {t(`dashboard.status.${summary.status}`)}
          </AppText>
        </View>
      </View>

      <AppText
        variant="label"
        color="textSecondary"
        style={{ marginTop: theme.spacing.md }}
      >
        {t('dashboard.safeToSpend')}
      </AppText>
      <MoneyText
        amount={summary.dailyAllowance}
        currencyCode={budget.currency}
        variant="displayLarge"
        color={statusColor}
      />

      <View style={{ marginTop: theme.spacing.md }}>
        <ProgressBar
          progress={summary.utilization}
          color={statusColor}
          label={t('dashboard.spent')}
        />
        <View style={[styles.progressLabels, { marginTop: theme.spacing.sm }]}>
          <View>
            <AppText variant="caption" color="textTertiary">
              {t('dashboard.spent')}
            </AppText>
            <MoneyText
              amount={summary.totalSpent}
              currencyCode={budget.currency}
              variant="subtitle"
            />
          </View>
          <View style={styles.alignEnd}>
            <AppText variant="caption" color="textTertiary">
              {t('dashboard.remaining')}
            </AppText>
            <MoneyText
              amount={summary.remaining}
              currencyCode={budget.currency}
              variant="subtitle"
              color={summary.remaining < 0 ? 'error' : 'textPrimary'}
            />
          </View>
        </View>
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  headerRow: { flexDirection: 'row', alignItems: 'flex-start' },
  statusPill: { alignSelf: 'flex-start' },
  progressLabels: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
  },
  alignEnd: { alignItems: 'flex-end' },
});
