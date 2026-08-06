import 'package:drift/native.dart';

import 'package:budget_tracker/core/database/app_database.dart';

/// Provides an open, in-memory [AppDatabase] for tests that exercise Drift
/// table access (export, backup, import). The schema is created fresh for each
/// test by triggering Drift's migration strategy on a new in-memory executor.
Future<AppDatabase> createInMemoryDatabase() async {
  final executor = NativeDatabase.memory();
  final database = AppDatabase(executor: executor);
  // Accessing a table triggers Drift to run the migration (onCreate for a
  // fresh database), creating the full schema.
  await database.select(database.expenses).get();
  return database;
}
