import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/investments/data/investments_repository.dart';
import 'package:hishab/features/investments/domain/investment.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

Map<String, Object?> content(BackupData data) =>
    data.toJson()..remove('exportedAt');

Map<String, Object?> jsonOf(BackupData data) =>
    jsonDecode(data.encode()) as Map<String, Object?>;

/// A database with a farm (money in through an account, profit, a value set,
/// money taken back) and a shop that is closed.
Future<AppDatabase> investedDatabase() async {
  final db = createTestDatabase();
  final cash = await insertTestAccount(db, name: 'Cash');
  final repo = InvestmentsRepository(db);
  final farm = await repo.createInvestment(
    name: 'Poultry farm',
    note: 'with Rahim, half',
    startedOn: DateTime(2026, 9, 1),
  );
  await repo.addEntry(
    farm,
    kind: InvestmentEntryKind.putIn,
    amount: 500000,
    date: DateTime(2026, 9, 2),
    accountId: cash,
  );
  await repo.addEntry(
    farm,
    kind: InvestmentEntryKind.profit,
    amount: 40000,
    date: DateTime(2026, 10, 2),
    note: 'first month',
    accountId: cash,
  );
  await repo.addEntry(
    farm,
    kind: InvestmentEntryKind.takeBack,
    amount: 100000,
    date: DateTime(2026, 10, 3),
  );
  await repo.setCurrentValue(farm, 450000);
  final shop = await repo.createInvestment(
    name: 'Shop',
    startedOn: DateTime(2026, 1, 1),
  );
  await repo.addEntry(
    shop,
    kind: InvestmentEntryKind.putIn,
    amount: 200000,
    date: DateTime(2026, 1, 5),
  );
  await repo.setClosed(shop, closed: true);
  return db;
}

Future<void> expectDamaged(
  void Function(Map<String, Object?> json) change,
  String message,
) async {
  final db = await investedDatabase();
  addTearDown(db.close);
  final json = jsonOf(await BackupRepository(db).buildBackup(now));
  change(json);
  expect(() => BackupData.fromJson(json), throwsValidation(message));
}

void main() {
  group('making a backup', () {
    test('holds the investments and their lines, with the links', () async {
      final db = await investedDatabase();
      addTearDown(db.close);

      final data = await BackupRepository(db).buildBackup(now);

      expect(data.investments.map((i) => i.name), ['Poultry farm', 'Shop']);
      expect(data.investments.first.currentValue, 450000);
      expect(data.investments.first.note, 'with Rahim, half');
      expect(data.investments.last.currentValue, isNull);
      expect(data.investments.last.isClosed, isTrue);
      expect(data.investmentEntries, hasLength(4));
      final withAccount = data.investmentEntries.first;
      expect(withAccount.kind, 'putIn');
      expect(withAccount.accountId, isNotNull);
      expect(withAccount.transactionId, isNotNull);
      expect(data.investmentEntries[2].transactionId, isNull);
    });

    test('is written as the current format version', () async {
      final db = await investedDatabase();
      addTearDown(db.close);

      final json = jsonOf(await BackupRepository(db).buildBackup(now));

      expect(json['formatVersion'], backupFormatVersion);
      expect(json['investments'], hasLength(2));
      expect(json['investmentEntries'], hasLength(4));
    });

    test('survives being written and read again', () async {
      final db = await investedDatabase();
      addTearDown(db.close);
      final first = await BackupRepository(db).buildBackup(now);

      final second = BackupData.decode(first.encode());

      expect(content(second), content(first));
    });
  });

  group('restoring', () {
    test(
      'brings the investments back exactly, into another database',
      () async {
        final db = await investedDatabase();
        addTearDown(db.close);
        final backup = BackupData.decode(
          (await BackupRepository(db).buildBackup(now)).encode(),
        );
        final other = createTestDatabase(seedDefaults: true);
        addTearDown(other.close);

        await BackupRepository(other).restore(backup);

        final restored = await BackupRepository(other).buildBackup(now);
        expect(content(restored), content(backup));
        // And it works: the sums come out the same.
        final farm =
            (await InvestmentsRepository(other).watchInvestments().first)
                .firstWhere((i) => i.investment.name == 'Poultry farm');
        expect(farm.putIn, 500000);
        expect(farm.profit, 40000);
        expect(farm.takenBack, 100000);
        expect(farm.totalReturn, 40000 + 100000 + 450000 - 500000);
      },
    );

    test('replaces the investments that were there', () async {
      final db = await investedDatabase();
      addTearDown(db.close);
      final empty = createTestDatabase();
      addTearDown(empty.close);
      await insertTestAccount(empty, name: 'Bank');
      final emptyBackup = await BackupRepository(empty).buildBackup(now);

      await BackupRepository(db).restore(emptyBackup);

      expect(await InvestmentsRepository(db).watchInvestments().first, isEmpty);
      expect(await db.investmentsDao.getAllEntries(), isEmpty);
    });

    test('an older file has none, and is read as having none', () async {
      final db = await investedDatabase();
      addTearDown(db.close);
      final json = jsonOf(await BackupRepository(db).buildBackup(now))
        ..['formatVersion'] = 10
        ..remove('investments')
        ..remove('investmentEntries');

      final data = BackupData.fromJson(json);

      expect(data.investments, isEmpty);
      expect(data.investmentEntries, isEmpty);
    });
  });

  group('a damaged file', () {
    test('with a line that points to an investment that is not there', () {
      return expectDamaged(
        (json) =>
            (json['investmentEntries'] as List<Object?>)
                    .cast<Map<String, Object?>>()
                    .first['investmentId'] =
                999,
        'investment line',
      );
    });

    test('with a line of a kind that does not exist', () {
      return expectDamaged(
        (json) =>
            (json['investmentEntries'] as List<Object?>)
                    .cast<Map<String, Object?>>()
                    .first['kind'] =
                'gift',
        'not a kind',
      );
    });

    test('with a line of no money', () {
      return expectDamaged(
        (json) =>
            (json['investmentEntries'] as List<Object?>)
                    .cast<Map<String, Object?>>()
                    .first['amount'] =
                0,
        'amount',
      );
    });

    test('with a line that points to an account that is not there', () {
      return expectDamaged(
        (json) =>
            (json['investmentEntries'] as List<Object?>)
                    .cast<Map<String, Object?>>()
                    .first['accountId'] =
                999,
        'account',
      );
    });

    test('with a line that points to a transaction that is not there', () {
      return expectDamaged(
        (json) =>
            (json['investmentEntries'] as List<Object?>)
                    .cast<Map<String, Object?>>()
                    .first['transactionId'] =
                999,
        'transaction',
      );
    });

    test('with two investments of the same id', () {
      return expectDamaged(
        (json) =>
            (json['investments'] as List<Object?>)
                .cast<Map<String, Object?>>()
                .last['id'] = (json['investments'] as List<Object?>)
                .cast<Map<String, Object?>>()
                .first['id'],
        'investments',
      );
    });

    test('with a value below zero', () {
      return expectDamaged(
        (json) =>
            (json['investments'] as List<Object?>)
                    .cast<Map<String, Object?>>()
                    .first['currentValue'] =
                -5,
        'below zero',
      );
    });

    test('with an investment that has no yes or no for closed', () {
      return expectDamaged(
        (json) =>
            (json['investments'] as List<Object?>)
                    .cast<Map<String, Object?>>()
                    .first['isClosed'] =
                'yes',
        'isClosed',
      );
    });
  });
}
