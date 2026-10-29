import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/data/drive_backup_service.dart';
import 'package:hishab/features/backup/data/drive_gateway.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_drive_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 24, 15, 30);

DriveBackupService serviceFor(AppDatabase db, FakeDriveGateway gateway) =>
    DriveBackupService(
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

Future<DriveBackupStatus> statusOf(AppDatabase db) async =>
    DriveBackupStatus.fromSettings(await db.settingsDao.getAll());

void main() {
  group('DriveBackupService', () {
    test(
      'turning on signs in, remembers the account and saves a copy',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        final gateway = FakeDriveGateway();
        await oneEntry(db);

        await serviceFor(db, gateway).turnOn(now);

        final status = await statusOf(db);
        expect(status.enabled, isTrue);
        expect(status.email, 'me@gmail.com');
        expect(status.lastSaved, now);
        expect(gateway.signInCalls, 1);
        expect(gateway.uploads.single.name, driveBackupFileName);
        // A copy in Drive counts as a backup, so Home stops asking for one.
        expect(
          (await db.settingsDao.getAll())[lastBackupKey],
          now.toIso8601String(),
        );
      },
    );

    test('a closed sign-in turns nothing on', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeDriveGateway()..signInFails = DriveProblem.cancelled;

      await expectLater(
        serviceFor(db, gateway).turnOn(now),
        throwsA(isA<DriveException>()),
      );

      expect((await statusOf(db)).enabled, isFalse);
    });

    test('saves nothing while it is off', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeDriveGateway()..signedIn = true;
      await oneEntry(db);

      final saved = await serviceFor(db, gateway).run(now);

      expect(saved, isFalse);
      expect(gateway.uploads, isEmpty);
    });

    test('saves nothing while there is no entry', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeDriveGateway();
      await seedBasics(db);

      await serviceFor(db, gateway).turnOn(now);

      expect(gateway.uploads, isEmpty);
    });

    test(
      'keeps the problem, and the line from Google, when it fails',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        final gateway = FakeDriveGateway()
          ..uploadFails = DriveProblem.notAllowed;
        await oneEntry(db);

        await serviceFor(db, gateway).turnOn(now);

        final status = await statusOf(db);
        expect(status.problem, DriveProblem.notAllowed);
        expect(status.detail, 'HTTP 403 test');
        expect(status.lastSaved, isNull);
        expect(status.enabled, isTrue);
      },
    );

    test('forgets the problem after it saves again', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeDriveGateway()..uploadFails = DriveProblem.failed;
      await oneEntry(db);
      final service = serviceFor(db, gateway);
      await service.turnOn(now);

      gateway.uploadFails = null;
      await service.run(now);

      final status = await statusOf(db);
      expect(status.problem, isNull);
      expect(status.lastSaved, now);
    });

    test('turning off forgets the account, not the copy in Drive', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeDriveGateway();
      await oneEntry(db);
      final service = serviceFor(db, gateway);
      await service.turnOn(now);

      await service.turnOff();

      final status = await statusOf(db);
      expect(status.enabled, isFalse);
      expect(status.email, isNull);
      expect(gateway.signOutCalls, 1);
    });

    test(
      'fetch reads the backup in Drive, asking to sign in if needed',
      () async {
        final source = createTestDatabase();
        addTearDown(source.close);
        await oneEntry(source);
        final text = (await BackupRepository(source).buildBackup(now)).encode();
        final db = createTestDatabase();
        addTearDown(db.close);
        final gateway = FakeDriveGateway()
          ..file = DriveFile(
            bytes: Uint8List.fromList(utf8.encode(text)),
            modified: now,
          );

        final data = await serviceFor(db, gateway).fetch();

        expect(gateway.signInCalls, 1);
        expect(data!.transactions.single.note, 'Lunch');
      },
    );

    test('fetch says null when Drive has no backup', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final gateway = FakeDriveGateway()..signedIn = true;

      expect(await serviceFor(db, gateway).fetch(), isNull);
    });

    test('the choice and the account stay out of a backup', () {
      for (final key in [
        driveEnabledKey,
        driveEmailKey,
        lastDriveBackupKey,
        driveProblemKey,
        driveDetailKey,
      ]) {
        expect(isDeviceSetting(key), isTrue, reason: key);
      }
    });
  });
}
