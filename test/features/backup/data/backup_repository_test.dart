import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/data/csv_import_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

/// A database with a bit of everything: an archived account, a sub-category,
/// a transfer, a balance correction, budgets, notes with awkward characters.
Future<AppDatabase> richDatabase() async {
  final db = createTestDatabase();
  final cash = await db.accountsDao.insertAccount(
    AccountsCompanion.insert(
      name: 'Cash',
      type: AccountType.cash,
      openingBalance: const Value(150000),
    ),
  );
  final bkash = await db.accountsDao.insertAccount(
    AccountsCompanion.insert(name: 'bKash', type: AccountType.mobileBanking),
  );
  final old = await db.accountsDao.insertAccount(
    AccountsCompanion.insert(
      name: 'Old bank',
      type: AccountType.bank,
      includeInTotal: const Value(false),
    ),
  );
  await db.accountsDao.setArchived(old, archived: true);
  final food = await insertTestCategory(db, name: 'Food');
  final groceries = await insertTestCategory(
    db,
    name: 'Groceries',
    parentId: food,
  );
  final salary = await insertTestCategory(
    db,
    name: 'Salary',
    type: CategoryType.income,
  );
  final archived = await insertTestCategory(db, name: 'Gone');
  await db.categoriesDao.setArchived(archived, archived: true);

  Future<void> add(
    TransactionType type,
    int amount,
    DateTime date, {
    int account = 0,
    int? to,
    int? category,
    String note = '',
    bool adjustment = false,
  }) => db.transactionsDao.insertTransaction(
    TransactionsCompanion.insert(
      type: type,
      amount: amount,
      accountId: account == 0 ? cash : account,
      toAccountId: Value(to),
      categoryId: Value(category),
      date: date,
      note: Value(note),
      isAdjustment: Value(adjustment),
    ),
  );
  await add(
    TransactionType.income,
    5000000,
    DateTime(2026, 10, 1, 10),
    category: salary,
  );
  await add(
    TransactionType.expense,
    25050,
    DateTime(2026, 10, 3, 13, 15),
    category: groceries,
    note: 'Lunch, "special"\nsecond line',
  );
  await add(
    TransactionType.expense,
    6000,
    DateTime(2026, 10, 4, 9),
    category: food,
  );
  await add(
    TransactionType.transfer,
    100000,
    DateTime(2026, 10, 5, 9),
    to: bkash,
    note: 'Cash out',
  );
  await add(
    TransactionType.income,
    20000,
    DateTime(2026, 10, 6, 9),
    category: salary,
    adjustment: true,
  );
  await db.budgetsDao.insertBudget(
    BudgetsCompanion.insert(month: '2026-10', amount: 3000000),
  );
  await db.budgetsDao.insertBudget(
    BudgetsCompanion.insert(
      month: '2026-10',
      amount: 800000,
      categoryId: Value(food),
    ),
  );
  return db;
}

/// What a backup says without the time it was made.
Map<String, Object?> content(BackupData data) =>
    data.toJson()..remove('exportedAt');

Future<ImportPlan> planFor(AppDatabase db, String csvText) async {
  final table = parseCsvTable(csvText);
  final mapping = ImportMapping(
    columns: guessColumns(table.headers),
    dateFormat:
        detectDateFormat(table.rows.map((r) => r[0])) ??
        SheetDateFormat.yearMonthDay,
    typeSource: TypeSource.column,
  );
  return buildImportPlan(
    table: table,
    mapping: mapping,
    context: await CsvImportRepository(db).loadContext(),
  );
}

void main() {
  late AppDatabase db;
  late BackupRepository repo;

  setUp(() async {
    db = await richDatabase();
    repo = BackupRepository(db);
  });
  tearDown(() => db.close());

  group('making a backup', () {
    test('holds everything, archived rows too, with its ids', () async {
      final data = await repo.buildBackup(now);

      expect(data.accounts.map((a) => a.name), ['Cash', 'bKash', 'Old bank']);
      expect(data.accounts.last.isArchived, isTrue);
      expect(data.accounts.last.includeInTotal, isFalse);
      expect(data.accounts.first.openingBalance, 150000);
      expect(data.categories.map((c) => c.name), [
        'Food',
        'Groceries',
        'Salary',
        'Gone',
      ]);
      expect(data.categories[1].parentId, data.categories[0].id);
      expect(data.categories.last.isArchived, isTrue);
      expect(data.transactions, hasLength(5));
      expect(data.transactions.where((t) => t.isAdjustment), hasLength(1));
      expect(data.budgets, hasLength(2));
      expect(data.exportedAt, now.toUtc());
    });

    test(
      'is a faithful picture: written, read and written again it is the same',
      () async {
        final first = await repo.buildBackup(now);

        final second = BackupData.decode(first.encode());

        expect(second.toJson(), first.toJson());
      },
    );
  });

  group('restoring', () {
    test(
      'a backup restored into another database makes it identical',
      () async {
        final backup = BackupData.decode(
          (await repo.buildBackup(now)).encode(),
        );
        final other = createTestDatabase(seedDefaults: true);
        addTearDown(other.close);

        await BackupRepository(other).restore(backup);

        final restored = await BackupRepository(other).buildBackup(now);
        expect(content(restored), content(backup));
      },
    );

    test('replaces what was there before', () async {
      final backup = await repo.buildBackup(now);
      final other = createTestDatabase(seedDefaults: true);
      addTearDown(other.close);
      expect(await other.accountsDao.getAll(), hasLength(4)); // the defaults

      await BackupRepository(other).restore(backup);

      final names = (await other.accountsDao.getAll(includeArchived: true))
          .map((a) => a.name);
      expect(names, ['Cash', 'bKash', 'Old bank']);
      expect(
        (await other.categoriesDao.getAll(includeArchived: true)).length,
        4,
      );
    });

    test('keeps the ids, so every link still points the right way', () async {
      final backup = await repo.buildBackup(now);
      final other = createTestDatabase();
      addTearDown(other.close);
      // Use up some ids first, so the numbers would differ without care.
      await insertTestAccount(other, name: 'Filler 1');
      await insertTestAccount(other, name: 'Filler 2');

      await BackupRepository(other).restore(backup);

      final transfer = (await other.transactionsDao.getAll()).firstWhere(
        (t) => t.type == TransactionType.transfer,
      );
      final from = (await other.accountsDao.getById(transfer.accountId))!;
      final to = (await other.accountsDao.getById(transfer.toAccountId!))!;
      expect(from.name, 'Cash');
      expect(to.name, 'bKash');
      final grocery = (await other.transactionsDao.getAll()).firstWhere(
        (t) => t.note.startsWith('Lunch'),
      );
      final category = (await other.categoriesDao.getById(
        grocery.categoryId!,
      ))!;
      expect(category.name, 'Groceries');
      expect(
        (await other.categoriesDao.getById(category.parentId!))!.name,
        'Food',
      );
    });

    test('account balances come back the same', () async {
      final before = await AccountsRepository(db)
          .watchAccounts(includeArchived: true)
          .first;
      final backup = await repo.buildBackup(now);
      final other = createTestDatabase();
      addTearDown(other.close);

      await BackupRepository(other).restore(backup);

      final after = await AccountsRepository(other)
          .watchAccounts(includeArchived: true)
          .first;
      expect(
        after.map((a) => (a.account.name, a.balance)),
        before.map((a) => (a.account.name, a.balance)),
      );
    });

    test('new rows added after a restore get new ids', () async {
      final backup = await repo.buildBackup(now);
      final other = createTestDatabase();
      addTearDown(other.close);
      await BackupRepository(other).restore(backup);
      final highest = backup.transactions
          .map((t) => t.id)
          .reduce((a, b) => a > b ? a : b);

      final newId = await other.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.expense,
          amount: 100,
          accountId: backup.accounts.first.id,
          categoryId: Value(backup.categories.first.id),
          date: DateTime(2026, 10, 12),
        ),
      );

      expect(newId, greaterThan(highest));
    });

    test('an empty backup empties the app', () async {
      final empty = BackupData(
        exportedAt: now,
        accounts: const [],
        categories: const [],
        transactions: const [],
        budgets: const [],
      );

      await repo.restore(empty);

      expect(await db.accountsDao.getAll(includeArchived: true), isEmpty);
      expect(await db.categoriesDao.getAll(includeArchived: true), isEmpty);
      expect(await db.transactionsDao.getAll(), isEmpty);
      expect(await db.budgetsDao.getAll(), isEmpty);
    });

    test(
      'is all or nothing: a backup the database refuses changes nothing',
      () async {
        final before = content(await repo.buildBackup(now));
        final backup = await repo.buildBackup(now);
        // A transaction of zero is not allowed by the database.
        final bad = BackupData(
          exportedAt: now,
          accounts: backup.accounts,
          categories: backup.categories,
          transactions: [
            for (final t in backup.transactions)
              BackupTransaction(
                id: t.id,
                type: t.type,
                amount: t.id == backup.transactions.last.id ? 0 : t.amount,
                accountId: t.accountId,
                toAccountId: t.toAccountId,
                categoryId: t.categoryId,
                date: t.date,
                note: t.note,
                isAdjustment: t.isAdjustment,
                createdAt: t.createdAt,
                updatedAt: t.updatedAt,
              ),
          ],
          budgets: backup.budgets,
        );

        await expectLater(
          repo.restore(bad),
          throwsValidation('nothing was changed'),
        );

        expect(content(await repo.buildBackup(now)), before);
      },
    );

    test('is all or nothing for a transfer to the same account too', () async {
      final before = content(await repo.buildBackup(now));
      final backup = await repo.buildBackup(now);
      final cash = backup.accounts.first.id;
      final bad = BackupData(
        exportedAt: now,
        accounts: backup.accounts,
        categories: backup.categories,
        transactions: [
          ...backup.transactions,
          BackupTransaction(
            id: 999,
            type: TransactionType.transfer,
            amount: 5,
            accountId: cash,
            toAccountId: cash,
            categoryId: null,
            date: now.toUtc(),
            note: '',
            isAdjustment: false,
            createdAt: now.toUtc(),
            updatedAt: now.toUtc(),
          ),
        ],
        budgets: backup.budgets,
      );

      await expectLater(
        repo.restore(bad),
        throwsValidation('nothing was changed'),
      );

      expect(content(await repo.buildBackup(now)), before);
    });

    test('streams see the change', () async {
      final backup = await repo.buildBackup(now);
      final other = createTestDatabase();
      addTearDown(other.close);
      final counts = <int>[];
      final subscription = other.accountsDao
          .watchAll(includeArchived: true)
          .listen((rows) => counts.add(rows.length));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await BackupRepository(other).restore(backup);
      await pumpEventQueue();

      expect(counts.first, 0);
      expect(counts.last, 3);
    });
  });

  group('exporting transactions to CSV', () {
    Future<List<List<String>>> exported() async {
      final text = await repo.exportTransactionsCsv();
      return parseCsvTable(text, hasHeader: false).rows;
    }

    test('starts with a header and a byte order mark', () async {
      final text = await repo.exportTransactionsCsv();

      expect(text.startsWith('﻿'), isTrue);
      expect((await exported()).first, [
        'Date',
        'Type',
        'Amount',
        'Account',
        'To account',
        'Category',
        'Note',
        'Correction',
        'USD',
        'Tag',
      ]);
    });

    test('has one row for each transaction, oldest first', () async {
      final rows = await exported();

      expect(rows.length, 1 + 5);
      expect(rows.skip(1).map((r) => r[0]), [
        '2026-10-01 10:00',
        '2026-10-03 13:15',
        '2026-10-04 09:00',
        '2026-10-05 09:00',
        '2026-10-06 09:00',
      ]);
    });

    test('writes amounts as plain taka with two decimals', () async {
      final rows = await exported();

      expect(rows.skip(1).map((r) => r[2]), [
        '50000.00',
        '250.50',
        '60.00',
        '1000.00',
        '200.00',
      ]);
    });

    test('writes type, accounts, category paths and corrections', () async {
      final rows = (await exported()).skip(1).toList();

      expect(rows[0].sublist(1, 7), [
        'income',
        '50000.00',
        'Cash',
        '',
        'Salary',
        '',
      ]);
      expect(rows[1][5], 'Food > Groceries');
      expect(rows[2][5], 'Food');
      expect(rows[3].sublist(1, 7), [
        'transfer',
        '1000.00',
        'Cash',
        'bKash',
        '',
        'Cash out',
      ]);
      expect(rows[3][7], '');
      expect(rows[4][7], 'yes');
      expect(rows[0][7], '');
    });

    test('quotes notes with commas, quotes and line breaks', () async {
      final rows = (await exported()).skip(1).toList();

      expect(rows[1][6], 'Lunch, "special"\nsecond line');
    });

    test('an empty app gives only the header', () async {
      final empty = createTestDatabase();
      addTearDown(empty.close);

      final rows = parseCsvTable(
        await BackupRepository(empty).exportTransactionsCsv(),
        hasHeader: false,
      ).rows;

      expect(rows, hasLength(1));
    });

    test(
      'can be imported again: into an empty app it makes the same transactions',
      () async {
        final text = await repo.exportTransactionsCsv();
        final other = createTestDatabase();
        addTearDown(other.close);

        final plan = await planFor(other, text);
        final result = await CsvImportRepository(other).apply(plan);

        expect(plan.errorCount, 0);
        expect(result.imported, 5);
        final original = await db.transactionsDao.getAll();
        final copy = await other.transactionsDao.getAll();
        List<(TransactionType, int, String)> summary(
          List<TransactionRow> rows,
        ) =>
            [for (final t in rows) (t.type, t.amount, t.note)]
              ..sort((a, b) => a.$2.compareTo(b.$2));
        expect(summary(copy), summary(original));
        // The category hierarchy came with it.
        final grocery = (await other.categoriesDao.getAll()).firstWhere(
          (c) => c.name == 'Groceries',
        );
        expect(
          (await other.categoriesDao.getById(grocery.parentId!))!.name,
          'Food',
        );
      },
    );

    test(
      'and importing it into the same app finds every row already there',
      () async {
        final plan = await planFor(db, await repo.exportTransactionsCsv());

        expect(plan.duplicateCount, 5);
        expect(plan.importCount, 0);
      },
    );
  });
}
