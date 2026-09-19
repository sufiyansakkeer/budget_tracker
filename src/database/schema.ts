import { appSchema, tableSchema } from '@nozbe/watermelondb';

/**
 * Local database schema.
 *
 * Two deliberate departures from the Flutter/drift schema:
 *
 * 1. Budgets store only `amount`. The old `remainingAmount` column was a
 *    denormalised cache that had to be rewritten on every expense change;
 *    remaining is now derived from the expense rows (see `summarizeBudget`),
 *    so it can never drift out of sync.
 * 2. Expenses store one `date` timestamp instead of separate date and time
 *    columns — a JS timestamp already carries both.
 */
export const schema = appSchema({
  version: 1,
  tables: [
    tableSchema({
      name: 'budgets',
      columns: [
        { name: 'name', type: 'string' },
        { name: 'amount', type: 'number' },
        { name: 'currency', type: 'string' },
        { name: 'start_date', type: 'number', isIndexed: true },
        { name: 'end_date', type: 'number' },
        { name: 'is_archived', type: 'boolean', isIndexed: true },
        { name: 'color', type: 'string', isOptional: true },
        { name: 'icon', type: 'string', isOptional: true },
        { name: 'notes', type: 'string', isOptional: true },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'categories',
      columns: [
        { name: 'name', type: 'string' },
        { name: 'icon', type: 'string' },
        { name: 'color_hex', type: 'string' },
        { name: 'is_system', type: 'boolean' },
      ],
    }),
    tableSchema({
      name: 'expenses',
      columns: [
        { name: 'budget_id', type: 'string', isIndexed: true },
        { name: 'category_id', type: 'string', isIndexed: true },
        { name: 'amount', type: 'number' },
        { name: 'note', type: 'string', isOptional: true },
        { name: 'date', type: 'number', isIndexed: true },
        { name: 'receipt_path', type: 'string', isOptional: true },
        { name: 'tags', type: 'string', isOptional: true },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
  ],
});
