import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
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
      expect(version.read<int>('user_version'), 2);
    },
  );

  test('a new database starts at version 2 with the column', () async {
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
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);
  });
}
