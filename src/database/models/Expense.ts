import { Model, type Relation } from '@nozbe/watermelondb';
import type { Associations } from '@nozbe/watermelondb/Model';
import {
  date,
  field,
  immutableRelation,
  json,
  readonly,
  relation,
  text,
} from '@nozbe/watermelondb/decorators';
import type Budget from './Budget';
import type Category from './Category';

/** Tags are stored as a JSON array; anything else in the column reads as empty. */
const sanitizeTags = (raw: unknown): string[] =>
  Array.isArray(raw) ? raw.filter((t): t is string => typeof t === 'string') : [];

/** A single spend, always attached to exactly one budget and one category. */
export default class Expense extends Model {
  static table = 'expenses';

  static associations: Associations = {
    budgets: { type: 'belongs_to', key: 'budget_id' },
    categories: { type: 'belongs_to', key: 'category_id' },
  };

  @field('budget_id') budgetId!: string;
  @field('category_id') categoryId!: string;
  @field('amount') amount!: number;
  @text('note') note!: string | null;
  /** Single timestamp carrying both the date and the time of the spend. */
  @date('date') date!: Date;
  @text('receipt_path') receiptPath!: string | null;
  @json('tags', sanitizeTags) tags!: string[];

  @readonly @date('created_at') createdAt!: Date;
  @readonly @date('updated_at') updatedAt!: Date;

  /** A spend cannot be moved between budgets — that would silently rewrite history. */
  @immutableRelation('budgets', 'budget_id') budget!: Relation<Budget>;
  @relation('categories', 'category_id') category!: Relation<Category>;
}
