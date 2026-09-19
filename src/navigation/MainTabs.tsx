import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useTranslation } from 'react-i18next';
import { Icon } from '../components/Icon';
import { BudgetListScreen } from '../features/budget/screens/BudgetListScreen';
import { DashboardScreen } from '../features/dashboard/screens/DashboardScreen';
import { ExpenseHistoryScreen } from '../features/expenses/screens/ExpenseHistoryScreen';
import { SettingsScreen } from '../features/settings/screens/SettingsScreen';
import { useTheme } from '../theme/ThemeProvider';
import type { MainTabParamList } from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();

const ICONS: Record<keyof MainTabParamList, string> = {
  Dashboard: 'space-dashboard',
  Expenses: 'receipt-long',
  Budgets: 'account-balance-wallet',
  Settings: 'settings',
};

export function MainTabs() {
  const theme = useTheme();
  const { t } = useTranslation();

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: theme.colors.primary,
        tabBarInactiveTintColor: theme.colors.textTertiary,
        tabBarStyle: {
          backgroundColor: theme.colors.surface,
          borderTopColor: theme.colors.divider,
        },
        tabBarLabelStyle: theme.typography.caption,
        // React Navigation's API takes a render function here; the lint rule
        // is aimed at components created inside a render tree, which this is not.
        // eslint-disable-next-line react/no-unstable-nested-components
        tabBarIcon: ({ color, size }) => (
          <Icon name={ICONS[route.name]} size={size} color={color} />
        ),
      })}
    >
      <Tab.Screen
        name="Dashboard"
        component={DashboardScreen}
        options={{ title: t('tabs.dashboard') }}
      />
      <Tab.Screen
        name="Expenses"
        component={ExpenseHistoryScreen}
        options={{ title: t('tabs.expenses') }}
      />
      <Tab.Screen
        name="Budgets"
        component={BudgetListScreen}
        options={{ title: t('tabs.budgets') }}
      />
      <Tab.Screen
        name="Settings"
        component={SettingsScreen}
        options={{ title: t('tabs.settings') }}
      />
    </Tab.Navigator>
  );
}
