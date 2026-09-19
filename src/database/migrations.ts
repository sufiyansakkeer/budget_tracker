import { schemaMigrations } from '@nozbe/watermelondb/Schema/migrations';

/**
 * Schema migrations.
 *
 * Empty at v1. Every future schema bump needs a matching entry here, or
 * existing installs will fail to open the database.
 */
export const migrations = schemaMigrations({
  migrations: [],
});
