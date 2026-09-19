import { Model } from '@nozbe/watermelondb';
import { field, text } from '@nozbe/watermelondb/decorators';

/** A spending category. System categories are seeded and cannot be deleted. */
export default class Category extends Model {
  static table = 'categories';

  @text('name') name!: string;
  /** MaterialIcons glyph name. */
  @text('icon') icon!: string;
  @text('color_hex') colorHex!: string;
  @field('is_system') isSystem!: boolean;
}
