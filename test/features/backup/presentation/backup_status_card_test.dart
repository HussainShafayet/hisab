import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/auto_backup_gateway.dart';
import 'package:hishab/features/backup/data/drive_gateway.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_auto_backup_gateway.dart';
import '../../../helpers/fake_drive_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

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

Future<void> openBackupScreen(
  WidgetTester tester,
  AppDatabase db,
  FakeDriveGateway drive,
) async {
  useTallScreen(tester);
  await pumpAppWithDatabase(
    tester,
    db,
    overrides: [
      driveGatewayProvider.overrideWithValue(drive),
      autoBackupGatewayProvider.overrideWithValue(FakeAutoBackupGateway()),
    ],
  );
  await openFromMore(tester, 'Backup & export');
}

/// The database answers in real time, not in the test's fake time.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await settle(tester);
}

String statusText(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  group('the backup status card on Backup & export', () {
    testWithDatabase('says Google Drive is off and offers to turn it on', (
      tester,
      db,
    ) async {
      await openBackupScreen(tester, db, FakeDriveGateway());

      expect(find.text('Is my data backed up?'), findsOneWidget);
      expect(statusText(tester, 'status-drive'), startsWith('Not on.'));
      expect(find.byKey(const ValueKey('status-drive-now')), findsNothing);
      expect(statusText(tester, 'status-auto'), contains('Not saved yet'));
    });

    testWithDatabase('turns on, saves a first copy and says when', (
      tester,
      db,
    ) async {
      await oneEntry(db);
      final drive = FakeDriveGateway();
      await openBackupScreen(tester, db, drive);

      await tapKey(tester, 'status-drive-on');

      expect(drive.signInCalls, 1);
      expect(drive.uploads, hasLength(1));
      final text = statusText(tester, 'status-drive');
      expect(text, startsWith('Saved '));
      expect(text, contains('just now'));
      expect(find.textContaining('me@gmail.com'), findsOneWidget);
    });

    testWithDatabase('Back up now saves again and says so', (tester, db) async {
      await oneEntry(db);
      final drive = FakeDriveGateway();
      await openBackupScreen(tester, db, drive);
      await tapKey(tester, 'status-drive-on');

      await tapKey(tester, 'status-drive-now');

      expect(drive.uploads, hasLength(2));
      expect(find.text('Saved to Google Drive.'), findsOneWidget);
    });

    testWithDatabase('shows the problem in the card when it fails', (
      tester,
      db,
    ) async {
      await oneEntry(db);
      final drive = FakeDriveGateway();
      await openBackupScreen(tester, db, drive);
      await tapKey(tester, 'status-drive-on');

      drive.uploadFails = DriveProblem.notAllowed;
      await tapKey(tester, 'status-drive-now');

      expect(
        statusText(tester, 'status-drive'),
        contains('Google did not allow it'),
      );
      expect(statusText(tester, 'status-drive'), contains('Last saved'));
    });

    testWithDatabase('keeps a list of the recent tries', (tester, db) async {
      await oneEntry(db);
      final drive = FakeDriveGateway();
      await openBackupScreen(tester, db, drive);
      await tapKey(tester, 'status-drive-on');
      drive.uploadFails = DriveProblem.noInternet;
      await tapKey(tester, 'status-drive-now');

      await tester.ensureVisible(find.byKey(const ValueKey('status-log')));
      await tester.tap(find.byKey(const ValueKey('status-log')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsWidgets);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWithDatabase('Check Drive says what is there, and how it compares', (
      tester,
      db,
    ) async {
      await oneEntry(db);
      final drive = FakeDriveGateway();
      await openBackupScreen(tester, db, drive);
      await tapKey(tester, 'status-drive-on');
      // Drive holds what the first save wrote.
      drive.file = DriveFile(
        bytes: Uint8List.fromList(drive.uploads.single.bytes),
        modified: DateTime.utc(2026, 10, 11, 8, 30),
      );

      await tapKey(tester, 'status-drive-check');

      expect(find.byKey(const ValueKey('drive-check-dialog')), findsOneWidget);
      expect(find.text('Your backup is in Google Drive'), findsOneWidget);
      expect(find.textContaining('1 transaction'), findsOneWidget);
      expect(
        find.text('Same number of transactions as on this phone.'),
        findsOneWidget,
      );
    });

    testWithDatabase('Check Drive says when nothing is there', (
      tester,
      db,
    ) async {
      await oneEntry(db);
      final drive = FakeDriveGateway();
      await openBackupScreen(tester, db, drive);
      await tapKey(tester, 'status-drive-on');
      drive.file = null;

      await tapKey(tester, 'status-drive-check');

      expect(find.text('No backup in Google Drive'), findsOneWidget);
    });

    testWithDatabase('Check Drive refuses a file that is not a backup', (
      tester,
      db,
    ) async {
      await oneEntry(db);
      final drive = FakeDriveGateway();
      await openBackupScreen(tester, db, drive);
      await tapKey(tester, 'status-drive-on');
      drive.file = DriveFile(
        bytes: Uint8List.fromList(utf8.encode('not json')),
        modified: null,
      );

      await tapKey(tester, 'status-drive-check');

      expect(
        find.text('The file in Google Drive is not a Hishab backup.'),
        findsOneWidget,
      );
    });
  });
}
