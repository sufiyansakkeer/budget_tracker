import { Model, type Query } from '@nozbe/watermelondb';
import type { Associations } from '@nozbe/watermelondb/Model';
import { children, date, field, readonly, text } from '@nozbe/watermelondb/decorators';
import type Expense from './Expense';

/**
 * A budget covering an arbitrary date range.
 *
 * `amount` is the total for the whole period, not per month — the Flutter
 * schema called it `monthlyAmount` for historical reasons and the name
 * outlived its meaning once custom ranges landed.
 *
 * There is no stored `remaining`: it is derived from the linked expenses so
 * the two can never disagree.
 */
export default class Budget extends Model {
  static table = 'budgets';

  static associations: Associations = {
    expenses: { type: 'has_many', foreignKey: 'budget_id' },
  };

  @text('name') name!: string;
  @field('amount') amount!: number;
  @text('currency') currency!: string;
  @date('start_date') startDate!: Date;
  @date('end_date') endDate!: Date;
  @field('is_archived') isArchived!: boolean;
  @text('color') color!: string | null;
  @text('icon') icon!: string | null;
  @text('notes') notes!: string | null;

  @readonly @date('created_at') createdAt!: Date;
  @readonly @date('updated_at') updatedAt!: Date;

  @children('expenses') expenses!: Query<Expense>;
}
