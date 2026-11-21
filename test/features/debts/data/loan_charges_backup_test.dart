import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/debt_charge.dart';

import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 25, 14, 30);

Map<String, Object?> _content(BackupData data) =>
    data.toJson()..remove('exportedAt');

Map<String, Object?> _jsonOf(BackupData data) =>
    jsonDecode(data.encode()) as Map<String, Object?>;

/// A loan I took, with a late fee that is also my expense, and interest that
/// is not.
Future<AppDatabase> _chargedDatabase() async {
  final db = createTestDatabase();
  final cash = await insertTestAccount(db, name: 'Cash');
  final repo = DebtsRepository(db);
  final id = await repo.createDebt(
    person: 'Rahim',
    direction: DebtDirection.borrowed,
    amount: 100000,
    openedOn: DateTime(2026, 10, 1, 10),
  );
  await repo.addCharge(
    id,
    amount: 5000,
    chargedOn: DateTime(2026, 10, 20, 9),
    kind: DebtChargeKind.lateFee,
    note: 'one week late',
    accountId: cash,
  );
  await repo.addCharge(
    id,
    amount: 2000,
    chargedOn: DateTime(2026, 10, 22, 9),
    kind: DebtChargeKind.interest,
  );
  await repo.addPayment(
    id,
    amount: 30000,
    paidOn: DateTime(2026, 10, 23, 9),
    accountId: cash,
    fee: 1500,
  );
  return db;
}

void main() {
  group('making a backup', () {
    test('holds the charges, with the links to their entries', () async {
      final db = await _chargedDatabase();
      addTearDown(db.close);

      final data = await BackupRepository(db).buildBackup(_now);

      expect(data.debtCharges, hasLength(2));
      final fee = data.debtCharges.firstWhere(
        (c) => c.kind == DebtChargeKind.lateFee,
      );
      expect(fee.amount, 5000);
      expect(fee.note, 'one week late');
      expect(fee.transactionId, isNotNull);
      expect(fee.expenseId, isNotNull);
      final interest = data.debtCharges.firstWhere(
        (c) => c.kind == DebtChargeKind.interest,
      );
      expect(interest.transactionId, isNull);
      expect(interest.expenseId, isNull);
    });

    test('holds the transfer charge of a payment', () async {
      final db = await _chargedDatabase();
      addTearDown(db.close);

      final data = await BackupRepository(db).buildBackup(_now);

      expect(data.debtPayments.single.feeTransactionId, isNotNull);
      final json = _jsonOf(data);
      expect(
        (json['debtPayments']! as List<Object?>)
            .cast<Map>()
            .single['feeTransactionId'],
        isNotNull,
      );
    });

    test('is written as the current format version', () async {
      final db = await _chargedDatabase();
      addTearDown(db.close);

      final json = _jsonOf(await BackupRepository(db).buildBackup(_now));

      expect(json['formatVersion'], backupFormatVersion);
      expect(backupFormatVersion, greaterThanOrEqualTo(14));
      expect(json['debtCharges'], hasLength(2));
    });

    test('survives being written and read again', () async {
      final db = await _chargedDatabase();
      addTearDown(db.close);
      final first = await BackupRepository(db).buildBackup(_now);

      final second = BackupData.decode(first.encode());

      expect(_content(second), _content(first));
    });
  });

  group('restoring', () {
    test('brings the charges back, into another database', () async {
      final db = await _chargedDatabase();
      addTearDown(db.close);
      final backup = BackupData.decode(
        (await BackupRepository(db).buildBackup(_now)).encode(),
      );
      final other = createTestDatabase(seedDefaults: true);
      addTearDown(other.close);

      await BackupRepository(other).restore(backup);

      final restored = await BackupRepository(other).buildBackup(_now);
      expect(_content(restored), _content(backup));
      final item = (await DebtsRepository(other).watchDebts().first).single;
      expect(item.charged, 7000);
      expect(item.remaining, 107000 - 30000);
      // The payment still knows its transfer charge, so taking it back
      // takes the charge back too.
      final payment = (await other.debtsDao.getAllPayments()).single;
      expect(payment.feeTransactionId, isNotNull);
      await DebtsRepository(other).deletePayment(payment.id);
      expect(
        await other.transactionsDao.getById(payment.feeTransactionId!),
        isNull,
      );
    });

    test('replaces the charges that were there', () async {
      final db = await _chargedDatabase();
      addTearDown(db.close);
      final empty = createTestDatabase();
      addTearDown(empty.close);
      await insertTestAccount(empty, name: 'Bank');
      final emptyBackup = await BackupRepository(empty).buildBackup(_now);

      await BackupRepository(db).restore(emptyBackup);

      expect(await db.debtsDao.getAllCharges(), isEmpty);
      expect(await db.debtsDao.getAllDebts(), isEmpty);
    });

    test('reads an older backup, which has no charges', () async {
      final db = await _chargedDatabase();
      addTearDown(db.close);
      final json = _jsonOf(await BackupRepository(db).buildBackup(_now))
        ..['formatVersion'] = 13
        ..remove('debtCharges');

      final data = BackupData.fromJson(json);

      expect(data.debtCharges, isEmpty);
      expect(data.debts, hasLength(1));
    });
  });

  group('a damaged file', () {
    Future<void> expectDamaged(
      void Function(Map<String, Object?> json) change,
      String message,
    ) async {
      final db = await _chargedDatabase();
      addTearDown(db.close);
      final json = _jsonOf(await BackupRepository(db).buildBackup(_now));
      change(json);
      expect(() => BackupData.fromJson(json), throwsValidation(message));
    }

    List<Map<String, Object?>> charges(Map<String, Object?> json) => [
      for (final c in json['debtCharges']! as List<Object?>)
        c! as Map<String, Object?>,
    ];

    test('with a charge on a loan that is not in it', () async {
      await expectDamaged(
        (json) => charges(json).first['debtId'] = 999,
        'points to a loan that is not in the file',
      );
    });

    test('with a charge whose expense is not in it', () async {
      await expectDamaged(
        (json) => charges(json).first['expenseId'] = 99999,
        'points to a transaction that is not in the file',
      );
    });

    test('with two charges of the same id', () async {
      await expectDamaged((json) {
        final list = charges(json);
        list[1]['id'] = list[0]['id'];
      }, 'loan charges');
    });

    test('with a charge of a kind the app does not know', () async {
      await expectDamaged(
        (json) => charges(json).first['kind'] = 'bribe',
        'kind',
      );
    });
  });
}
