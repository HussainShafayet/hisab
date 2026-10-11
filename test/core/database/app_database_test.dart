import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';

import '../../helpers/test_database.dart';

void main() {
  group('schema', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    test('has the indexes the queries rely on', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final names = rows.map((row) => row.read<String>('name')).toSet();

      expect(
        names,
        containsAll([
          'idx_transactions_date',
          'idx_transactions_account_id',
          'idx_transactions_to_account_id',
          'idx_transactions_category_id',
          'idx_budgets_month_category',
        ]),
      );
    });

    test('enforces foreign keys', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.read<int>('foreign_keys'), 1);
    });

    test('starts empty when seeding is switched off', () async {
      expect(await db.accountsDao.getAll(includeArchived: true), isEmpty);
      expect(await db.categoriesDao.getAll(includeArchived: true), isEmpty);
    });
  });

  test('seeds only when the database file is first created', () async {
    final dir = Directory.systemTemp.createTempSync('hishab_db_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    var db = AppDatabase.withExecutor(NativeDatabase(file));
    final accounts = await db.accountsDao.getAll();
    final categoryCount = (await db.categoriesDao.getAll()).length;
    expect(accounts, isNotEmpty);

    // The user archives a default account, then restarts the app.
    await db.accountsDao.setArchived(accounts.first.id, archived: true);
    await db.close();

    db = AppDatabase.withExecutor(NativeDatabase(file));
    addTearDown(() => db.close());

    expect(await db.accountsDao.getAll(), hasLength(accounts.length - 1));
    expect(await db.categoriesDao.getAll(), hasLength(categoryCount));
  });
}
