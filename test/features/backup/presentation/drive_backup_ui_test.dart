import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/auto_backup_gateway.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/data/drive_gateway.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_auto_backup_gateway.dart';
import '../../../helpers/fake_drive_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

final driveSwitch = find.byKey(const ValueKey('drive-backup'));
final driveStatus = find.byKey(const ValueKey('drive-backup-status'));

Future<void> leaveApp(WidgetTester tester) async {
  final binding = tester.binding;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  // The database answers in real time, not in the test's fake time.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

Future<void> returnToApp(WidgetTester tester) async {
  final binding = tester.binding;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

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

Future<void> pumpWith(
  WidgetTester tester,
  AppDatabase db,
  FakeDriveGateway drive,
) => pumpAppWithDatabase(
  tester,
  db,
  overrides: [
    driveGatewayProvider.overrideWithValue(drive),
    autoBackupGatewayProvider.overrideWithValue(FakeAutoBackupGateway()),
  ],
);

Future<void> openSettingsAtDrive(WidgetTester tester) async {
  await openFromMore(tester, 'Settings');
  await tester.scrollUntilVisible(
    driveSwitch,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  // Right into view, not just its edge.
  await tester.ensureVisible(driveSwitch);
  await tester.pumpAndSettle();
}

void main() {
  group('the backup to Google Drive in Settings', () {
    testWithDatabase('is off to begin with', (tester, db) async {
      useTallScreen(tester);
      await pumpWith(tester, db, FakeDriveGateway());
      await openSettingsAtDrive(tester);

      expect(tester.widget<SwitchListTile>(driveSwitch).value, isFalse);
      expect(driveStatus, findsNothing);
    });

    testWithDatabase('signs in when switched on and says which account', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await oneEntry(db);
      final drive = FakeDriveGateway();
      await pumpWith(tester, db, drive);
      await openSettingsAtDrive(tester);

      await tester.tap(driveSwitch);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      expect(drive.signInCalls, 1);
      expect(drive.uploads, hasLength(1));
      expect(tester.widget<SwitchListTile>(driveSwitch).value, isTrue);
      expect(
        tester.widget<Text>(driveStatus).data,
        startsWith('Signed in as me@gmail.com. Saved '),
      );
    });

    testWithDatabase('stays off when the sign-in is closed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final drive = FakeDriveGateway()..signInFails = DriveProblem.cancelled;
      await pumpWith(tester, db, drive);
      await openSettingsAtDrive(tester);

      await tester.tap(driveSwitch);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(driveSwitch).value, isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWithDatabase('says what Google said when it cannot save', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await oneEntry(db);
      final drive = FakeDriveGateway()..uploadFails = DriveProblem.notAllowed;
      await pumpWith(tester, db, drive);
      await openSettingsAtDrive(tester);

      await tester.tap(driveSwitch);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(driveStatus).data, contains('HTTP 403 test'));
    });

    testWithDatabase('turns off and forgets the account', (tester, db) async {
      useTallScreen(tester);
      await oneEntry(db);
      await db.settingsDao.put(driveEnabledKey, 'true');
      await db.settingsDao.put(driveEmailKey, 'me@gmail.com');
      final drive = FakeDriveGateway()..signedIn = true;
      await pumpWith(tester, db, drive);
      await openSettingsAtDrive(tester);

      await tester.tap(driveSwitch);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(driveSwitch).value, isFalse);
      expect(drive.signOutCalls, 1);
    });
  });

  group('the copy in Google Drive', () {
    testWithDatabase('is written when the app is left', (tester, db) async {
      useTallScreen(tester);
      await oneEntry(db);
      await db.settingsDao.put(driveEnabledKey, 'true');
      final drive = FakeDriveGateway()..signedIn = true;
      await pumpWith(tester, db, drive);

      await leaveApp(tester);

      expect(drive.uploads, hasLength(1));
    });

    testWithDatabase('is tried again after a failure', (tester, db) async {
      useTallScreen(tester);
      await oneEntry(db);
      await db.settingsDao.put(driveEnabledKey, 'true');
      final drive = FakeDriveGateway()
        ..signedIn = true
        ..uploadFails = DriveProblem.noInternet;
      await pumpWith(tester, db, drive);
      await leaveApp(tester);
      expect(drive.uploads, isEmpty);
      await returnToApp(tester);
      drive.uploadFails = null;

      await leaveApp(tester);

      expect(drive.uploads, hasLength(1));
    });

    testWithDatabase('is not written when it is off', (tester, db) async {
      useTallScreen(tester);
      await oneEntry(db);
      final drive = FakeDriveGateway()..signedIn = true;
      await pumpWith(tester, db, drive);

      await leaveApp(tester);

      expect(drive.uploads, isEmpty);
    });
  });

  group('restoring from Google Drive', () {
    testWithDatabase('brings the backup in Drive back after asking', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final source = createTestDatabase();
      addTearDown(source.close);
      await oneEntry(source);
      final text = (await BackupRepository(
        source,
      ).buildBackup(DateTime(2026, 10, 10))).encode();
      final drive = FakeDriveGateway()
        ..file = DriveFile(
          bytes: Uint8List.fromList(utf8.encode(text)),
          modified: DateTime(2026, 10, 10),
        );
      await pumpWith(tester, db, drive);
      await openFromMore(tester, 'Backup & export');

      await tester.tap(find.byKey(const ValueKey('restore-drive')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(drive.signInCalls, 1);
      await tester.tap(find.text('Replace everything'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();

      final restored = await tester.runAsync(db.transactionsDao.getAll);
      expect(restored!.single.note, 'Lunch');
    });

    testWithDatabase('says so when Drive has no backup', (tester, db) async {
      useTallScreen(tester);
      final drive = FakeDriveGateway()..signedIn = true;
      await pumpWith(tester, db, drive);
      await openFromMore(tester, 'Backup & export');

      await tester.tap(find.byKey(const ValueKey('restore-drive')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No backup in Google Drive'), findsOneWidget);
    });
  });
}
