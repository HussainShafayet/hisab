import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:hishab/features/accounts/data/accounts_dao.dart';
import 'package:hishab/features/accounts/data/accounts_table.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/budget/data/budgets_dao.dart';
import 'package:hishab/features/budget/data/budgets_table.dart';
import 'package:hishab/features/categories/data/categories_dao.dart';
import 'package:hishab/features/categories/data/categories_table.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/debts/data/debts_dao.dart';
import 'package:hishab/features/debts/data/debts_table.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/recurring/data/recurring_dao.dart';
import 'package:hishab/features/recurring/data/recurring_table.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/reports/data/reports_dao.dart';
import 'package:hishab/features/settings/data/app_settings_table.dart';
import 'package:hishab/features/settings/data/settings_dao.dart';
import 'package:hishab/features/transactions/data/transactions_dao.dart';
import 'package:hishab/features/transactions/data/transactions_table.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

part 'app_database.g.dart';

/// One overall budget (null category) and one budget per category, per month.
/// SQLite treats NULLs as distinct in a plain UNIQUE constraint, so the null
/// category is mapped to 0 (ids start at 1) to make it unique too.
final _budgetsMonthCategoryUnique = Index(
  'idx_budgets_month_category',
  'CREATE UNIQUE INDEX idx_budgets_month_category '
      'ON budgets (month, IFNULL(category_id, 0))',
);

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Budgets,
    AppSettings,
    Debts,
    DebtPayments,
    RecurringRules,
  ],
  daos: [
    AccountsDao,
    CategoriesDao,
    TransactionsDao,
    BudgetsDao,
    ReportsDao,
    SettingsDao,
    DebtsDao,
    RecurringDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// The real database file on the phone.
  AppDatabase() : this.withExecutor(driftDatabase(name: 'hishab'));

  /// Used by tests with `NativeDatabase.memory()`. Pass `seedDefaults: false`
  /// to start with empty tables.
  AppDatabase.withExecutor(super.executor, {this.seedDefaults = true});

  final bool seedDefaults;

  /// 1: first version.
  /// 2: `transactions.is_adjustment`.
  /// 3: the `app_settings` table (Settings).
  /// 4: the `debts` and `debt_payments` tables (dhar / baki).
  /// 5: the `recurring_rules` table.
  /// 6: `accounts.credit_limit` and `accounts.bill_due_day` (credit cards).
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await migrator.createIndex(_budgetsMonthCategoryUnique);
      if (seedDefaults) {
        await accountsDao.insertDefaults();
        await categoriesDao.insertDefaults();
      }
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(transactions, transactions.isAdjustment);
        // Mark the corrections that were saved before the column existed:
        // everything in the "Balance adjustment" categories.
        await customStatement(
          'UPDATE transactions SET is_adjustment = 1 '
          'WHERE category_id IN (SELECT id FROM categories '
          "WHERE name = '$balanceAdjustmentCategoryName' "
          'AND parent_id IS NULL)',
        );
      }
      if (from < 3) {
        await migrator.createTable(appSettings);
      }
      if (from < 4) {
        await migrator.createTable(debts);
        await migrator.createTable(debtPayments);
      }
      if (from < 5) {
        await migrator.createTable(recurringRules);
      }
      if (from < 6) {
        await migrator.addColumn(accounts, accounts.creditLimit);
        await migrator.addColumn(accounts, accounts.billDueDay);
      }
    },
    beforeOpen: (details) async {
      // SQLite ignores foreign keys unless this is switched on for every
      // connection. It is what stops an account or category that still has
      // transactions from being deleted.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
