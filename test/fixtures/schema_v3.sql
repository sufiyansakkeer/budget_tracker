-- Schema v3: schema_v4.sql without the bills tables (bills,
-- bill_payments, index_bills_due_date), i.e. a database from before bills
-- existed. Upgrading it runs the `from < 4` createTable(bills) step with the
-- current Bills definition, which proves the later column guards hold.
CREATE TABLE "budgets" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "monthly_amount" REAL NOT NULL, "remaining_amount" REAL NOT NULL, "currency" TEXT NOT NULL, "month" INTEGER NULL, "year" INTEGER NULL, "start_date" INTEGER NOT NULL, "end_date" INTEGER NOT NULL, "is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), "color" TEXT NULL, "icon" TEXT NULL, "notes" TEXT NULL, "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), PRIMARY KEY ("id"));
CREATE TABLE "categories" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "icon" TEXT NOT NULL, "color_hex" TEXT NOT NULL, "is_system" INTEGER NOT NULL DEFAULT 1 CHECK ("is_system" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "expenses" ("id" TEXT NOT NULL, "budget_id" TEXT NOT NULL REFERENCES budgets (id), "amount" REAL NOT NULL, "category_id" TEXT NOT NULL REFERENCES categories (id), "note" TEXT NULL, "date" INTEGER NOT NULL, "time" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "receipt_image_path" TEXT NULL, "tags" TEXT NULL, "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), PRIMARY KEY ("id"));
CREATE TABLE "recurring_expenses" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "amount" REAL NOT NULL, "category_id" TEXT NOT NULL REFERENCES categories (id), "frequency" TEXT NOT NULL, "next_due_date" INTEGER NOT NULL, "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "savings_goals" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "target_amount" REAL NOT NULL, "current_amount" REAL NOT NULL DEFAULT 0.0, "target_date" INTEGER NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"));
CREATE INDEX index_expenses_budget ON expenses (budget_id);
CREATE INDEX index_expenses_category ON expenses (category_id);
CREATE INDEX index_expenses_date ON expenses (date);
