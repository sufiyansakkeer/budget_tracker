import type { NavigatorScreenParams } from '@react-navigation/native';

export type MainTabParamList = {
  Dashboard: undefined;
  /** `budgetId` pre-filters the history when arriving from a budget. */
  Expenses: { budgetId?: string } | undefined;
  Budgets: undefined;
  Settings: undefined;
};

export type RootStackParamList = {
  Onboarding: undefined;
  Main: NavigatorScreenParams<MainTabParamList>;
  /** Omit `expenseId` to create; pass it to edit. */
  ExpenseForm: { expenseId?: string; budgetId?: string } | undefined;
  ExpenseDetails: { expenseId: string };
  BudgetForm: { budgetId?: string } | undefined;
  BudgetDetails: { budgetId: string };
};

/**
 * Makes `navigation.navigate(...)` type-check against `RootStackParamList`
 * everywhere, including from inside the tab navigator.
 */
declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}
