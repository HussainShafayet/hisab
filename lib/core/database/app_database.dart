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
  tables: [Accounts, Categories, Transactions, Budgets],
  daos: [AccountsDao, CategoriesDao, TransactionsDao, BudgetsDao],
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
  @override
  int get schemaVersion => 2;

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
    },
    beforeOpen: (details) async {
      // SQLite ignores foreign keys unless this is switched on for every
      // connection. It is what stops an account or category that still has
      // transactions from being deleted.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
