import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_file_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

// testNow is Sunday 11 October 2026, 2:30 pm.
final card = find.byKey(const ValueKey('backup-reminder-card'));
final sendNow = find.byKey(const ValueKey('backup-now'));

/// Ten entries, so the backup reminder has a reason to come.
Future<void> tenEntries(AppDatabase db) async {
  final b = await seedBasics(db);
  for (var i = 0; i < 10; i++) {
    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 1000 + i,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 1 + i, 12),
      note: 'Entry $i',
    );
  }
}

void main() {
  group('the reminder card with the automatic backup on', () {
    testWithDatabase('offers to send a copy away', (tester, db) async {
      useTallScreen(tester);
      await tenEntries(db);
      await pumpAppWithDatabase(tester, db);

      expect(card, findsOneWidget);
      expect(find.text('Send a copy'), findsOneWidget);
      expect(find.textContaining('lost with the phone'), findsOneWidget);
    });

    testWithDatabase('opens the share sheet with the backup in one tap', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await tenEntries(db);
      final gateway = FakeFileGateway();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );

      await tester.tap(sendNow);
      await tester.pumpAndSettle();

      expect(gateway.shared, hasLength(1));
      expect(gateway.shared.single.fileName, 'hishab-backup-2026-10-11.json');
      final backup = BackupData.decode(gateway.shared.single.text);
      expect(backup.transactions, hasLength(10));
    });

    testWithDatabase('stops asking once the copy was sent', (tester, db) async {
      useTallScreen(tester);
      await tenEntries(db);
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(FakeFileGateway())],
      );

      await tester.tap(sendNow);
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });

    testWithDatabase('keeps asking when the share sheet fails', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await tenEntries(db);
      final gateway = FakeFileGateway()..failure = Exception('no share');
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [fileGatewayProvider.overrideWithValue(gateway)],
      );

      await tester.tap(sendNow);
      await tester.pumpAndSettle();

      expect(card, findsOneWidget);
    });
  });

  group('the reminder card with the automatic backup off', () {
    testWithDatabase('still says back up now', (tester, db) async {
      useTallScreen(tester);
      await tenEntries(db);
      await SettingsRepository(db).update((p) => p.copyWith(autoBackup: false));
      await pumpAppWithDatabase(tester, db);

      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Send a copy'), findsNothing);
    });
  });
}
