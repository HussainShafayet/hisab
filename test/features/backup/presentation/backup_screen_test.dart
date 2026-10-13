import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_file_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

/// Opens More, then Backup & export.
Future<void> openBackup(WidgetTester tester) =>
    openFromMore(tester, 'Backup & export');

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// A database with two accounts, three categories and two transactions.
Future<Basics> seed(AppDatabase db) async {
  final b = await seedBasics(db);
  await addTransaction(
    db,
    type: TransactionType.expense,
    amount: 25000,
    accountId: b.cash,
    categoryId: b.food,
    date: DateTime(2026, 10, 3, 12),
    note: 'Lunch',
  );
  await addTransaction(
    db,
    type: TransactionType.income,
    amount: 5000000,
    accountId: b.bkash,
    categoryId: b.salary,
    date: DateTime(2026, 10, 1, 9),
  );
  return b;
}

/// The text of a backup of a different database, to restore from.
Future<String> otherBackupText({int transactions = 3}) async {
  final other = createTestDatabase();
  final b = await seedBasics(other);
  for (var i = 1; i <= transactions; i++) {
    await addTransaction(
      other,
      type: TransactionType.expense,
      amount: i * 1000,
      accountId: b.cash,
      categoryId: b.transport,
      date: DateTime(2026, 9, i, 10),
    );
  }
  final text = (await BackupRepository(
    other,
  ).buildBackup(DateTime(2026, 10, 1))).encode();
  await other.close();
  return text;
}

void main() {
  late FakeFileGateway gateway;

  setUp(() => gateway = FakeFileGateway());

  testWithDatabase('lists what can be done', (tester, db) async {
    await pumpAppWithDatabase(
      tester,
      db,
      overrides: [fileGatewayProvider.overrideWithValue(gateway)],
    );
    await openBackup(tester);

    expect(appBarTitle('Backup & export'), findsOneWidget);
    for (final key in [
      'export-backup',
      'restore-backup',
      'export-csv',
      'import-csv',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(
      find.textContaining('never sends your data anywhere'),
      findsOneWidget,
    );
  });

  group('exporting a backup', () {
    testWithDatabase('saves everything to a file named with today\'s date', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'export-backup');
      await tapKey(tester, 'deliver-save');

      final file = gateway.saved.single;
      expect(file.fileName, 'hishab-backup-2026-10-11.json');
      expect(file.mimeType, 'application/json');
      final backup = BackupData.decode(file.text);
      expect(backup.accounts.map((a) => a.name), ['Cash', 'bKash']);
      expect(backup.transactions, hasLength(2));
      expect(backup.exportedAt, testNow.toUtc());
      expect(find.text('Backup saved.'), findsOneWidget);
    });

    testWithDatabase('can be shared instead', (tester, db) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'export-backup');
      await tapKey(tester, 'deliver-share');

      expect(gateway.saved, isEmpty);
      expect(gateway.shared.single.fileName, 'hishab-backup-2026-10-11.json');
      expect(
        BackupData.decode(gateway.shared.single.text).transactions,
        hasLength(2),
      );
    });

    testWithDatabase('says nothing when the save dialog is cancelled', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      gateway.saveResult = false;
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'export-backup');
      await tapKey(tester, 'deliver-save');

      expect(gateway.saved, hasLength(1));
      expect(find.text('Backup saved.'), findsNothing);
    });

    testWithDatabase('does nothing when the choice is dismissed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'export-backup');
      await tester.tapAt(const Offset(450, 100)); // outside the sheet
      await tester.pumpAndSettle();

      expect(gateway.saved, isEmpty);
      expect(gateway.shared, isEmpty);
    });

    testWithDatabase('says so when saving fails', (tester, db) async {
      useTallScreen(tester);
      gateway.failure = Exception('disk full');
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'export-backup');
      await tapKey(tester, 'deliver-save');

      expect(find.text('Could not export the backup'), findsOneWidget);
      expect(find.textContaining('disk full'), findsOneWidget);
    });
  });

  group('exporting transactions', () {
    testWithDatabase(
      'saves a CSV with a header and a row for each transaction',
      (tester, db) async {
        useTallScreen(tester);
        await seed(db);
        await pumpAppWithDatabase(
          tester,
          db,
          overrides: [fileGatewayProvider.overrideWithValue(gateway)],
        );
        await openBackup(tester);

        await tapKey(tester, 'export-csv');
        await tapKey(tester, 'deliver-save');

        final file = gateway.saved.single;
        expect(file.fileName, 'hishab-transactions-2026-10-11.csv');
        expect(file.mimeType, 'text/csv');
        expect(file.bytes.take(3), [0xEF, 0xBB, 0xBF]); // UTF-8 byte order mark
        final lines = const LineSplitter().convert(file.text);
        expect(
          lines.first,
          'Date,Type,Amount,Account,To account,Category,Note,Correction,USD,Tag',
        );
        expect(lines, hasLength(3));
        expect(lines[1], contains('2026-10-01 09:00,income,50000.00,bKash'));
        expect(lines[2], contains('2026-10-03 12:00,expense,250.00,Cash'));
        expect(find.text('Transactions saved.'), findsOneWidget);
      },
    );
  });

  group('restoring', () {
    testWithDatabase('asks first, then replaces everything', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      gateway.pickText('backup.json', await otherBackupText(transactions: 3));
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'restore-backup');

      expect(gateway.pickRequests.single, ['json']);
      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(
        find.textContaining(
          '2 accounts, 3 categories, 3 transactions and 0 budgets',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Everything on this phone now will be replaced'),
        findsOneWidget,
      );
      // Nothing has changed yet.
      expect(await db.transactionsDao.getAll(), hasLength(2));

      await tapText(tester, 'Replace everything');

      expect(await db.transactionsDao.getAll(), hasLength(3));
      expect(find.text('Backup restored: 3 transactions.'), findsOneWidget);
    });

    testWithDatabase('Cancel keeps everything as it was', (tester, db) async {
      useTallScreen(tester);
      await seed(db);
      gateway.pickText('backup.json', await otherBackupText());
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'restore-backup');
      await tapText(tester, 'Cancel');

      expect(await db.transactionsDao.getAll(), hasLength(2));
      expect(find.textContaining('Backup restored'), findsNothing);
    });

    testWithDatabase('does nothing when no file is chosen', (tester, db) async {
      useTallScreen(tester);
      await seed(db);
      gateway.picked = null;
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'restore-backup');

      expect(find.text('Restore this backup?'), findsNothing);
      expect(await db.transactionsDao.getAll(), hasLength(2));
    });

    testWithDatabase('refuses a file that is not a backup', (tester, db) async {
      useTallScreen(tester);
      await seed(db);
      gateway.pickText('notes.json', '{"hello": "world"}');
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'restore-backup');

      expect(find.text('This backup cannot be restored'), findsOneWidget);
      expect(find.text('This file is not a Hishab backup.'), findsOneWidget);
      expect(await db.transactionsDao.getAll(), hasLength(2));
    });

    testWithDatabase('refuses a file that is not even text', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      gateway.picked = PickedFile(
        name: 'x.json',
        bytes: Uint8List.fromList([0xFF, 0xFE, 0x00, 0x80]),
      );
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'restore-backup');

      expect(find.text('This file is not a Hishab backup.'), findsOneWidget);
    });

    testWithDatabase('refuses a backup from a newer version of the app', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      final json = jsonDecode(await otherBackupText()) as Map<String, Object?>;
      json['formatVersion'] = backupFormatVersion + 1;
      gateway.pickText('new.json', jsonEncode(json));
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'restore-backup');

      expect(find.textContaining('newer version of Hishab'), findsOneWidget);
      expect(await db.transactionsDao.getAll(), hasLength(2));
    });

    testWithDatabase('refuses a damaged backup and says what is wrong', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      final json = jsonDecode(await otherBackupText()) as Map<String, Object?>;
      ((json['transactions']! as List).first
              as Map<String, Object?>)['accountId'] =
          999;
      gateway.pickText('damaged.json', jsonEncode(json));
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'restore-backup');

      expect(find.textContaining('The backup is damaged'), findsOneWidget);
      expect(await db.transactionsDao.getAll(), hasLength(2));
    });

    testWithDatabase('if the database refuses it, nothing changes', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seed(db);
      final json = jsonDecode(await otherBackupText()) as Map<String, Object?>;
      ((json['transactions']! as List).last as Map<String, Object?>)['amount'] =
          0;
      gateway.pickText('bad.json', jsonEncode(json));
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'restore-backup');
      await tapText(tester, 'Replace everything');

      expect(find.text('Could not restore the backup'), findsOneWidget);
      expect(find.textContaining('nothing was changed'), findsOneWidget);
      expect(await db.transactionsDao.getAll(), hasLength(2));
      expect((await db.accountsDao.getAll()).map((a) => a.name), [
        'Cash',
        'bKash',
      ]);
    });

    testWithDatabase('says so when the file cannot be opened', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      gateway.failure = Exception('no permission');
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);

      await tapKey(tester, 'restore-backup');

      expect(find.text('Could not open the file'), findsOneWidget);
    });

    testWithDatabase('a backup of this very app restores to the same data', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seed(db);
      await db.budgetsDao.insertBudget(
        BudgetsCompanion.insert(
          month: '2026-10',
          amount: 100000,
          categoryId: Value(b.food),
        ),
      );
      final before = (await BackupRepository(db).buildBackup(testNow)).toJson()
        ..remove('exportedAt');
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );
      await openBackup(tester);
      await tapKey(tester, 'export-backup');
      await tapKey(tester, 'deliver-save');
      gateway.pickText('backup.json', gateway.saved.single.text);

      // Change something, then bring the backup back.
      await db.transactionsDao.deleteTransaction(
        (await db.transactionsDao.getAll()).first.id,
      );
      await tapKey(tester, 'restore-backup');
      await tapText(tester, 'Replace everything');

      final after = (await BackupRepository(db).buildBackup(testNow)).toJson()
        ..remove('exportedAt');
      expect(after, before);
    });
  });
}
