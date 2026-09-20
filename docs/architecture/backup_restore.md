# Backup, restore, export and import

Four related features with different jobs. With no server behind the app,
these are how a user moves to a new phone or recovers from a mistake.

| Action | Format | Scope | Effect |
| --- | --- | --- | --- |
| Back up | JSON (`monivo_backup`) | Everything | A complete, restorable snapshot |
| Restore | JSON (`monivo_backup`) | Everything | **Replaces** all current data |
| Export CSV | CSV | Expenses | A spreadsheet to read or re-import |
| Export JSON | JSON | Budgets, categories, expenses, settings | A readable data dump |
| Import CSV | CSV | Expenses | **Adds** expenses to the active budget |
| Import JSON | JSON | Tables present in the file | Inserts or replaces by id |

## Backup format

`BackupService.buildBackupPayload` writes:

```jsonc
{
  "type": "monivo_backup",
  "backupFormatVersion": 2,
  "metadata": {
    "createdAt": "…",        // ISO 8601
    "appVersion": "1.2.3",   // read from package_info_plus, never hard-coded
    "schemaVersion": 5       // the database schema it came from
  },
  "data": { "budgets": [...], "categories": [...], "expenses": [...],
            "settings": { "themeMode": "dark", ... },
            "bills": [...], "billPayments": [...],
            "recurringExpenses": [...], "savingsGoals": [...] }
}
```

Restore validates before it touches anything: the `type` marker, the presence
of metadata, a schema version no newer than this build, and the shape of each
record. Only then does it run — delete-all followed by insert-all, in one
transaction, so a failure leaves the existing data intact rather than half
replaced. A backup from an older schema restores fine; one from a newer build
is refused with an explanation instead of corrupting the database.

## CSV round trip

Export writes one row per expense with the header

```
id,date,time,amount,currency,category,categoryId,budget,budgetId,note,tags,receipt
```

Import reads that file back losslessly. It matches **columns by header name**,
not by position, ignoring case, spaces and underscores, so a spreadsheet the
user rearranged still imports and a minimal file with just `date`, `amount`
and `category` works. Quoted fields and embedded commas are handled by the
CSV parser rather than `split(',')`.

Unknown categories are resolved by name and otherwise fall back to "Others",
and an unknown budget falls back to the active budget, so an import can never
fail on a foreign key. Invalid rows (no amount, unparseable date) are skipped
and the rest are written in one transaction; the user is told how many landed.

Receipt **images are not included** in any format — only the stored path.
A restore on a new device will show "Receipt file is missing" for those
expenses.

## What is not covered

- No automatic or scheduled backups; the user exports deliberately.
- No cloud destination. The share sheet hands the file to whatever the user
  chooses.
- Restoring does not merge. If merging matters, import JSON instead, which
  inserts or replaces by id.

## Tests

- `test/features/settings/domain/services/backup_service_test.dart` and
  `backup_validation_test.dart` — payload shape, validation, refusal of newer
  schemas.
- `test/features/settings/domain/services/export_service_test.dart` and
  `import_service_test.dart` — the CSV round trip and header mapping.
