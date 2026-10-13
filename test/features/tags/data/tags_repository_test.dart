import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/tags/data/tags_repository.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

void main() {
  late AppDatabase db;
  late TagsRepository tags;
  late TransactionsRepository transactions;
  late int cash;
  late int bkash;
  late int food;
  late int salary;

  setUp(() async {
    db = createTestDatabase();
    tags = TagsRepository(db);
    transactions = TransactionsRepository(db);
    cash = await insertTestAccount(db, name: 'Cash');
    bkash = await insertTestAccount(db, name: 'bKash');
    food = await insertTestCategory(db, name: 'Food');
    salary = await insertTestCategory(
      db,
      name: 'Gift',
      type: CategoryType.income,
    );
  });
  tearDown(() => db.close());

  Future<int> spend(
    int amount, {
    int? tag,
    DateTime? on,
    TransactionType type = TransactionType.expense,
  }) => transactions.addTransaction(
    TransactionInput(
      type: type,
      amount: amount,
      accountId: cash,
      categoryId: type == TransactionType.income ? salary : food,
      date: on ?? DateTime(2026, 10, 5),
      tagId: tag,
    ),
  );

  group('a tag', () {
    test('is made with a trimmed name', () async {
      final id = await tags.createTag('  Cox\'s Bazar ');

      expect((await tags.getTag(id))!.name, 'Cox\'s Bazar');
    });

    test('needs a name that fits', () async {
      await expectLater(tags.createTag('  '), throwsValidation('name'));
      await expectLater(
        tags.createTag('x' * 41),
        throwsValidation('40 characters'),
      );
    });

    test('has a name of its own, whatever the case', () async {
      await tags.createTag('Eid');

      await expectLater(tags.createTag('eid'), throwsValidation('already'));
    });

    test('can be renamed, and keep its own name', () async {
      final id = await tags.createTag('Eid');
      await tags.createTag('Tour');

      await tags.renameTag(id, 'EID');
      expect((await tags.getTag(id))!.name, 'EID');
      await expectLater(
        tags.renameTag(id, 'tour'),
        throwsValidation('already'),
      );
    });

    test('cannot be renamed once gone', () async {
      await expectLater(tags.renameTag(99, 'X'), throwsValidation('not found'));
    });

    test('lists the newest first', () async {
      await tags.createTag('A');
      await tags.createTag('B');

      final list = await tags.watchTags().first;

      expect(list.map((t) => t.name), ['B', 'A']);
    });
  });

  group('a transaction with a tag', () {
    test('keeps it, and shows its name', () async {
      final tag = await tags.createTag('Tour');
      final id = await spend(5000, tag: tag);

      final item = (await transactions.getTransaction(id))!;

      expect(item.tagId, tag);
      expect(item.tagName, 'Tour');
    });

    test('can change or lose its tag when edited', () async {
      final a = await tags.createTag('A');
      final b = await tags.createTag('B');
      final id = await spend(5000, tag: a);
      TransactionInput withTag(int? tag) => TransactionInput(
        type: TransactionType.expense,
        amount: 5000,
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 10, 5),
        tagId: tag,
      );

      await transactions.updateTransaction(id, withTag(b));
      expect((await transactions.getTransaction(id))!.tagId, b);

      await transactions.updateTransaction(id, withTag(null));
      expect((await transactions.getTransaction(id))!.tagId, isNull);
    });

    test('comes back with an undone delete', () async {
      final tag = await tags.createTag('Tour');
      final id = await spend(5000, tag: tag);

      final deleted = (await transactions.deleteTransaction(id))!;
      await transactions.restoreTransaction(deleted);

      expect((await transactions.getTransaction(id))!.tagId, tag);
    });

    test('needs a tag that exists', () async {
      await expectLater(spend(5000, tag: 99), throwsValidation('not found'));
    });

    test('cannot be a transfer', () async {
      final tag = await tags.createTag('Tour');

      await expectLater(
        transactions.addTransaction(
          TransactionInput(
            type: TransactionType.transfer,
            amount: 1000,
            accountId: cash,
            toAccountId: bkash,
            date: DateTime(2026, 10, 5),
            tagId: tag,
          ),
        ),
        throwsValidation('transfer'),
      );
    });

    test('is listed under its tag, newest first', () async {
      final tag = await tags.createTag('Tour');
      final other = await tags.createTag('Eid');
      final a = await spend(1000, tag: tag, on: DateTime(2026, 10, 1));
      final b = await spend(2000, tag: tag, on: DateTime(2026, 10, 3));
      await spend(9000, tag: other);
      await spend(8000);

      final list = await transactions.watchByTag(tag).first;

      expect(list.map((t) => t.id), [b, a]);
    });
  });

  group('the summary of a tag', () {
    test('adds up what was spent and received, and counts', () async {
      final tag = await tags.createTag('Tour');
      await spend(1000, tag: tag, on: DateTime(2026, 10, 1));
      await spend(2500, tag: tag, on: DateTime(2026, 10, 3));
      await spend(700, tag: tag, type: TransactionType.income);

      final summary = (await tags.watchSummaries().first).single;

      expect(summary.expense, 3500);
      expect(summary.income, 700);
      expect(summary.net, 2800);
      expect(summary.count, 3);
      expect(summary.firstDate, DateTime(2026, 10, 1));
      expect(summary.lastDate, DateTime(2026, 10, 5));
    });

    test('leaves out balance corrections', () async {
      final tag = await tags.createTag('Tour');
      final id = await spend(1000, tag: tag);
      await db.customStatement(
        'UPDATE transactions SET is_adjustment = 1 WHERE id = $id',
      );

      final summary = (await tags.watchSummaries().first).single;

      expect(summary.expense, 0);
    });

    test('is empty for a tag that is not used yet', () async {
      await tags.createTag('Tour');

      final summary = (await tags.watchSummaries().first).single;

      expect(summary.count, 0);
      expect(summary.expense, 0);
      expect(summary.firstDate, isNull);
    });

    test('lists the tag used most recently first', () async {
      final old = await tags.createTag('Old');
      final recent = await tags.createTag('Recent');
      await spend(100, tag: old, on: DateTime(2026, 9, 1));
      await spend(100, tag: recent, on: DateTime(2026, 10, 9));
      final unused = await tags.createTag('Unused');

      final list = await tags.watchSummaries().first;

      expect(list.map((s) => s.tag.id), [recent, old, unused]);
    });
  });

  group('deleting a tag', () {
    test('keeps its transactions, without the tag', () async {
      final tag = await tags.createTag('Tour');
      final id = await spend(5000, tag: tag);

      await tags.deleteTag(tag);

      expect(await tags.getTag(tag), isNull);
      final item = (await transactions.getTransaction(id))!;
      expect(item.tagId, isNull);
      expect(item.tagName, isNull);
      expect(item.amount, 5000);
    });

    test('leaves the other tags alone', () async {
      final a = await tags.createTag('A');
      final b = await tags.createTag('B');
      final id = await spend(5000, tag: b);

      await tags.deleteTag(a);

      expect((await transactions.getTransaction(id))!.tagId, b);
    });
  });

  group('backup', () {
    test('keeps tags and the tag of a transaction', () async {
      final tag = await tags.createTag('Tour');
      final id = await spend(5000, tag: tag);
      final backup = await BackupRepository(db).buildBackup(now);

      final other = createTestDatabase();
      addTearDown(other.close);
      await BackupRepository(other).restore(BackupData.decode(backup.encode()));

      expect((await TagsRepository(other).getTag(tag))!.name, 'Tour');
      expect(
        (await TransactionsRepository(other).getTransaction(id))!.tagId,
        tag,
      );
    });

    test('an older backup without tags still restores', () async {
      final tag = await tags.createTag('Tour');
      await spend(5000, tag: tag);
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      json['formatVersion'] = 6;
      json.remove('tags');
      for (final t in (json['transactions']! as List).cast<Map>()) {
        t.remove('tagId');
      }

      final read = BackupData.fromJson(json);

      expect(read.tags, isEmpty);
      expect(read.transactions.first.tagId, isNull);
    });

    test('refuses a transaction with a tag that is not in the file', () async {
      final tag = await tags.createTag('Tour');
      await spend(5000, tag: tag);
      final backup = await BackupRepository(db).buildBackup(now);
      final json = jsonDecode(backup.encode()) as Map<String, Object?>;
      json['tags'] = <Object?>[];

      expect(() => BackupData.fromJson(json), throwsValidation('tag'));
    });

    test('exports the tag in the spreadsheet', () async {
      final tag = await tags.createTag('Tour');
      await spend(5000, tag: tag);

      final csv = await BackupRepository(db).exportTransactionsCsv();

      expect(csv, contains(',Tour'));
    });
  });
}
