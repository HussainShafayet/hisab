import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 11, 14, 30);

Map<String, Object?> content(BackupData data) =>
    data.toJson()..remove('exportedAt');

Map<String, Object?> jsonOf(BackupData data) =>
    jsonDecode(data.encode()) as Map<String, Object?>;

/// A database with a loan I gave (with a payment) and one I took.
Future<AppDatabase> loanDatabase() async {
  final db = createTestDatabase();
  final cash = await insertTestAccount(db, name: 'Cash');
  final repo = DebtsRepository(db);
  final lent = await repo.createDebt(
    person: 'Rahim',
    direction: DebtDirection.lent,
    amount: 100000,
    openedOn: DateTime(2026, 10, 5, 10),
    dueOn: DateTime(2026, 11, 1),
    note: 'for rent',
    accountId: cash,
  );
  await repo.addPayment(
    lent,
    amount: 30000,
    paidOn: DateTime(2026, 10, 8, 9),
    note: 'first part',
    accountId: cash,
  );
  await repo.createDebt(
    person: 'Karim',
    direction: DebtDirection.borrowed,
    amount: 20000,
    openedOn: DateTime(2026, 10, 6, 10),
  );
  return db;
}

Future<void> expectDamaged(
  void Function(Map<String, Object?> json) change,
  String message,
) async {
  final db = await loanDatabase();
  addTearDown(db.close);
  final json = jsonOf(await BackupRepository(db).buildBackup(now));
  change(json);
  expect(() => BackupData.fromJson(json), throwsValidation(message));
}

void main() {
  group('making a backup', () {
    test('holds the loans and their payments, with the links', () async {
      final db = await loanDatabase();
      addTearDown(db.close);

      final data = await BackupRepository(db).buildBackup(now);

      expect(data.debts.map((d) => d.person), ['Rahim', 'Karim']);
      expect(data.debtPayments.single.amount, 30000);
      expect(data.debts.first.transactionId, isNotNull);
      expect(data.debts.first.accountId, isNotNull);
      expect(data.debts.last.transactionId, isNull);
      expect(data.debts.first.dueOn, isNotNull);
      expect(data.debts.last.dueOn, isNull);
    });

    test('is written as the current format version', () async {
      final db = await loanDatabase();
      addTearDown(db.close);

      final json = jsonOf(await BackupRepository(db).buildBackup(now));

      expect(json['formatVersion'], backupFormatVersion);
      expect(json['debts'], hasLength(2));
      expect(json['debtPayments'], hasLength(1));
    });

    test('survives being written and read again', () async {
      final db = await loanDatabase();
      addTearDown(db.close);
      final first = await BackupRepository(db).buildBackup(now);

      final second = BackupData.decode(first.encode());

      expect(content(second), content(first));
    });
  });

  group('restoring', () {
    test('brings the loans back exactly, into another database', () async {
      final db = await loanDatabase();
      addTearDown(db.close);
      final backup = BackupData.decode(
        (await BackupRepository(db).buildBackup(now)).encode(),
      );
      final other = createTestDatabase(seedDefaults: true);
      addTearDown(other.close);

      await BackupRepository(other).restore(backup);

      final restored = await BackupRepository(other).buildBackup(now);
      expect(content(restored), content(backup));
      // And it works: the loan can be read with its payment.
      final item = (await DebtsRepository(
        other,
      ).watchDebts().first).firstWhere((i) => i.debt.person == 'Rahim');
      expect(item.paid, 30000);
      expect(item.remaining, 70000);
    });

    test('replaces the loans that were there', () async {
      final db = await loanDatabase();
      addTearDown(db.close);
      final empty = createTestDatabase();
      addTearDown(empty.close);
      await insertTestAccount(empty, name: 'Bank');
      final emptyBackup = await BackupRepository(empty).buildBackup(now);

      await BackupRepository(db).restore(emptyBackup);

      expect(await db.debtsDao.getAllDebts(), isEmpty);
      expect(await db.debtsDao.getAllPayments(), isEmpty);
      expect(
        await db.transactionsDao.getBetween(DateTime(2000), DateTime(2100)),
        isEmpty,
      );
    });

    test('reads a version 1 backup, which has no loans', () async {
      final db = await loanDatabase();
      addTearDown(db.close);
      final json = jsonOf(await BackupRepository(db).buildBackup(now))
        ..['formatVersion'] = 1
        ..remove('debts')
        ..remove('debtPayments');

      final data = BackupData.fromJson(json);

      expect(data.debts, isEmpty);
      expect(data.debtPayments, isEmpty);
      final other = createTestDatabase();
      addTearDown(other.close);
      await BackupRepository(other).restore(data);
      expect(await other.debtsDao.getAllDebts(), isEmpty);
      expect(await other.accountsDao.getAll(), hasLength(1));
    });

    test('keeps loans that have no account or transaction', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      await DebtsRepository(db).createDebt(
        person: 'Salma',
        direction: DebtDirection.borrowed,
        amount: 5000,
        openedOn: DateTime(2026, 10, 1),
      );
      final backup = await BackupRepository(db).buildBackup(now);
      final other = createTestDatabase();
      addTearDown(other.close);

      await BackupRepository(other).restore(backup);

      final debt = (await other.debtsDao.getAllDebts()).single;
      expect(debt.person, 'Salma');
      expect(debt.accountId, isNull);
      expect(debt.transactionId, isNull);
    });
  });

  group('a damaged backup', () {
    test('a payment of a loan that is not in the file', () async {
      await expectDamaged(
        (j) =>
            ((j['debtPayments']! as List).first
                    as Map<String, Object?>)['debtId'] =
                999,
        'loan payment',
      );
    });

    test(
      'a loan that points at a transaction that is not in the file',
      () async {
        await expectDamaged(
          (j) =>
              ((j['debts']! as List).first
                      as Map<String, Object?>)['transactionId'] =
                  9999,
          'loan',
        );
      },
    );

    test('a loan that points at an account that is not in the file', () async {
      await expectDamaged(
        (j) =>
            ((j['debts']! as List).first as Map<String, Object?>)['accountId'] =
                9999,
        'account that is not in the file',
      );
    });

    test('two loans with the same id', () async {
      await expectDamaged(
        (j) => ((j['debts']! as List).last as Map<String, Object?>)['id'] =
            ((j['debts']! as List).first as Map<String, Object?>)['id'],
        'two loans have the id',
      );
    });

    test('a loan with a missing field', () async {
      await expectDamaged(
        (j) => ((j['debts']! as List).first as Map<String, Object?>).remove(
          'person',
        ),
        'person',
      );
    });

    test('a loan with a direction it does not know', () async {
      await expectDamaged(
        (j) =>
            ((j['debts']! as List).first as Map<String, Object?>)['direction'] =
                'sideways',
        'direction',
      );
    });
  });
}
