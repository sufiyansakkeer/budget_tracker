import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useTranslation } from 'react-i18next';
import { BudgetDetailsScreen } from '../features/budget/screens/BudgetDetailsScreen';
import { BudgetFormScreen } from '../features/budget/screens/BudgetFormScreen';
import { ExpenseDetailsScreen } from '../features/expenses/screens/ExpenseDetailsScreen';
import { ExpenseFormScreen } from '../features/expenses/screens/ExpenseFormScreen';
import { OnboardingScreen } from '../features/onboarding/screens/OnboardingScreen';
import { useAppSelector } from '../store/hooks';
import { selectOnboardingCompleted } from '../store/slices/settingsSlice';
import { useTheme } from '../theme/ThemeProvider';
import { MainTabs } from './MainTabs';
import { toNavigationTheme } from './navigationTheme';
import type { RootStackParamList } from './types';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  const theme = useTheme();
  const { t } = useTranslation();
  const onboardingCompleted = useAppSelector(selectOnboardingCompleted);

  return (
    <NavigationContainer theme={toNavigationTheme(theme)}>
      <Stack.Navigator
        screenOptions={{
          headerStyle: { backgroundColor: theme.colors.surface },
          headerTitleStyle: theme.typography.title,
          headerTintColor: theme.colors.textPrimary,
          contentStyle: { backgroundColor: theme.colors.background },
        }}
      >
        {onboardingCompleted ? (
          <Stack.Group>
            <Stack.Screen
              name="Main"
              component={MainTabs}
              options={{ headerShown: false }}
            />
            <Stack.Screen
              name="ExpenseDetails"
              component={ExpenseDetailsScreen}
              options={{ title: t('expenses.title') }}
            />
            <Stack.Screen
              name="BudgetDetails"
              component={BudgetDetailsScreen}
              options={{ title: t('budgets.title') }}
            />
            {/* Forms are modals: they are a side trip, not a place in the
                navigation hierarchy you can go "back" through. */}
            <Stack.Group screenOptions={{ presentation: 'modal' }}>
              <Stack.Screen
                name="ExpenseForm"
                component={ExpenseFormScreen}
                options={{ title: t('expenses.add') }}
              />
              <Stack.Screen
                name="BudgetForm"
                component={BudgetFormScreen}
                options={{ title: t('budgets.add') }}
              />
            </Stack.Group>
          </Stack.Group>
        ) : (
          <Stack.Screen
            name="Onboarding"
            component={OnboardingScreen}
            options={{ headerShown: false }}
          />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
}
