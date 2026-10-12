import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/categories/domain/system_categories.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

void main() {
  test(
    'upgrading from version 1 adds is_adjustment and marks old corrections',
    () async {
      final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/test.sqlite');

      // Build a database as the first version of the app left it: no
      // is_adjustment column, user_version 1, with a correction in it.
      var db = AppDatabase.withExecutor(
        NativeDatabase(file),
        seedDefaults: false,
      );
      final account = await db.accountsDao.insertAccount(
        AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
      );
      final food = await db.categoriesDao.insertCategory(
        CategoriesCompanion.insert(name: 'Food', type: CategoryType.expense),
      );
      final correction = await db.categoriesDao.insertCategory(
        CategoriesCompanion.insert(
          name: balanceAdjustmentCategoryName,
          type: CategoryType.income,
        ),
      );
      Future<int> add(int category, int amount, TransactionType type) =>
          db.transactionsDao.insertTransaction(
            TransactionsCompanion.insert(
              type: type,
              amount: amount,
              accountId: account,
              categoryId: Value(category),
              date: DateTime(2026, 10, 5),
            ),
          );
      final adjustmentId = await add(correction, 20000, TransactionType.income);
      final normalId = await add(food, 5000, TransactionType.expense);
      await db.customStatement(
        'ALTER TABLE transactions DROP COLUMN is_adjustment',
      );
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();

      // Opening it with the current app runs the upgrade.
      db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
      addTearDown(db.close);

      final adjustment = (await db.transactionsDao.getById(adjustmentId))!;
      final normal = (await db.transactionsDao.getById(normalId))!;
      expect(adjustment.isAdjustment, isTrue);
      expect(normal.isAdjustment, isFalse);
      // Nothing else was touched.
      expect(adjustment.amount, 20000);
      expect(normal.amount, 5000);
      expect(adjustment.categoryId, correction);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      // Every upgrade step ran, up to the current version.
      expect(version.read<int>('user_version'), 6);
    },
  );

  test('upgrading from version 2 adds the settings table', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    // A database as version 2 left it: no app_settings table.
    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    final account = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
    );
    await db.customStatement('DROP TABLE app_settings');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    // The table exists and works, and what was there is untouched.
    await db.settingsDao.put('language', 'bangla');
    expect(await db.settingsDao.getAll(), {'language': 'bangla'});
    expect((await db.accountsDao.getById(account))!.name, 'Cash');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 6);
  });

  test('upgrading from version 3 adds the loan tables', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    final account = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
    );
    await db.customStatement('DROP TABLE debt_payments');
    await db.customStatement('DROP TABLE debts');
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    // Both tables exist and work, and what was there is untouched.
    final debt = await db.debtsDao.insertDebt(
      DebtsCompanion.insert(
        person: 'Rahim',
        direction: DebtDirection.lent,
        amount: 1000,
        openedOn: DateTime(2026, 10, 5),
      ),
    );
    await db.debtsDao.insertPayment(
      DebtPaymentsCompanion.insert(
        debtId: debt,
        amount: 400,
        paidOn: DateTime(2026, 10, 6),
      ),
    );
    expect((await db.debtsDao.getWithPaid(debt))!.paid, 400);
    expect((await db.accountsDao.getById(account))!.name, 'Cash');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 6);
  });

  test('upgrading from version 5 adds the credit card columns', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(
      NativeDatabase(file),
      seedDefaults: false,
    );
    final account = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(name: 'Cash', type: AccountType.cash),
    );
    await db.customStatement('ALTER TABLE accounts DROP COLUMN credit_limit');
    await db.customStatement('ALTER TABLE accounts DROP COLUMN bill_due_day');
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file), seedDefaults: false);
    addTearDown(db.close);

    // The account that was there has no limit and no bill day.
    final old = (await db.accountsDao.getById(account))!;
    expect(old.name, 'Cash');
    expect(old.creditLimit, isNull);
    expect(old.billDueDay, isNull);
    // And a credit card can use both.
    final card = await db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        name: 'Visa',
        type: AccountType.creditCard,
        creditLimit: const Value(5000000),
        billDueDay: const Value(15),
      ),
    );
    final saved = (await db.accountsDao.getById(card))!;
    expect(saved.creditLimit, 5000000);
    expect(saved.billDueDay, 15);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 6);
  });

  test(
    'a new database starts at the current version with the column',
    () async {
      final db = AppDatabase.withExecutor(
        NativeDatabase.memory(),
        seedDefaults: false,
      );
      addTearDown(db.close);

      final columns = await db
          .customSelect('PRAGMA table_info(transactions)')
          .get();
      expect(
        columns.map((c) => c.read<String>('name')),
        contains('is_adjustment'),
      );
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(
        tables.map((t) => t.read<String>('name')),
        contains('app_settings'),
      );
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 6);
      expect(
        tables.map((t) => t.read<String>('name')),
        containsAll(['debts', 'debt_payments', 'recurring_rules']),
      );
    },
  );
}
