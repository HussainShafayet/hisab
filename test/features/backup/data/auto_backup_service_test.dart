import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/auto_backup_gateway.dart';
import 'package:hishab/features/backup/data/auto_backup_service.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_auto_backup_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 24, 15, 30);

AutoBackupService serviceFor(AppDatabase db, FakeAutoBackupGateway gateway) =>
    AutoBackupService(
      db: db,
      repository: BackupRepository(db),
      gateway: gateway,
    );

Future<void> oneEntry(AppDatabase db) async {
  final b = await seedBasics(db);
  await addTransaction(
    db,
    type: TransactionType.expense,
    amount: 25000,
    accountId: b.cash,
    categoryId: b.food,
    date: DateTime(2026, 10, 3),
    note: 'Lunch',
  );
}

void main() {
  group('AutoBackupService', () {
    test('writes everything to the backup file', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeAutoBackupGateway();
      await oneEntry(db);

      final saved = await serviceFor(db, gateway).run(now);

      expect(saved, isTrue);
      expect(gateway.saved, hasLength(1));
      expect(gateway.saved.single.name, autoBackupFileName);
      final restored = BackupData.decode(
        utf8.decode(gateway.saved.single.bytes),
      );
      expect(restored.transactions.single.note, 'Lunch');
    });

    test('remembers when it saved, on this phone only', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      await oneEntry(db);

      await serviceFor(db, FakeAutoBackupGateway()).run(now);

      final status = AutoBackupStatus.fromSettings(
        await db.settingsDao.getAll(),
      );
      expect(status.lastSaved, now);
      expect(status.problem, isNull);
      expect(isDeviceSetting(lastAutoBackupKey), isTrue);
      expect(isDeviceSetting(autoBackupProblemKey), isTrue);
    });

    test('writes nothing while there is no entry', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeAutoBackupGateway();
      await seedBasics(db);

      final saved = await serviceFor(db, gateway).run(now);

      expect(saved, isFalse);
      expect(gateway.saved, isEmpty);
    });

    test('keeps the problem when the phone says no', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeAutoBackupGateway()
        ..failWith = AutoBackupProblem.oldAndroid;
      await oneEntry(db);

      final saved = await serviceFor(db, gateway).run(now);

      expect(saved, isFalse);
      final status = AutoBackupStatus.fromSettings(
        await db.settingsDao.getAll(),
      );
      expect(status.problem, AutoBackupProblem.oldAndroid);
      expect(status.lastSaved, isNull);
    });

    test('forgets the problem after it saves again', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeAutoBackupGateway()
        ..failWith = AutoBackupProblem.failed;
      await oneEntry(db);
      final service = serviceFor(db, gateway);
      await service.run(now);

      gateway.failWith = null;
      await service.run(now);

      final status = AutoBackupStatus.fromSettings(
        await db.settingsDao.getAll(),
      );
      expect(status.problem, isNull);
      expect(status.lastSaved, now);
    });
  });
}
