import { Database } from '@nozbe/watermelondb';
import SQLiteAdapter from '@nozbe/watermelondb/adapters/sqlite';
import { migrations } from './migrations';
import Budget from './models/Budget';
import Category from './models/Category';
import Expense from './models/Expense';
import { schema } from './schema';

const adapter = new SQLiteAdapter({
  dbName: 'smart_monivo',
  schema,
  migrations,
  // JSI is deliberately off. patches/@nozbe+watermelondb+0.28.0.patch makes
  // installWatermelonJSI a no-op on iOS: RN 0.87 builds with
  // RCT_REMOVE_LEGACY_ARCH=1, which removed RCTCxxBridge and with it the only
  // supported way to reach the jsi::Runtime from a plain RCTBridgeModule.
  //
  // Asking for `jsi: true` anyway does not enable it — getDispatcherType falls
  // back to the async bridge dispatcher either way, and only logs a misleading
  // "forgot to recompile" warning on every launch. Revisit when WatermelonDB
  // ships a codegen TurboModule.
  jsi: false,
  onSetUpError: error => {
    console.error('[Database] Failed to open', error);
  },
});

export const database = new Database({
  adapter,
  modelClasses: [Budget, Category, Expense],
});

export const collections = {
  budgets: database.get<Budget>('budgets'),
  categories: database.get<Category>('categories'),
  expenses: database.get<Expense>('expenses'),
};

export { Budget, Category, Expense };
