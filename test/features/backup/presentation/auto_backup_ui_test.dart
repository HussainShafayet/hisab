import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/backup/data/auto_backup_gateway.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fake_auto_backup_gateway.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

/// Leaves the app, the way pressing Home does.
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

/// Comes back to the app.
Future<void> returnToApp(WidgetTester tester) async {
  final binding = tester.binding;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  group('the automatic backup', () {
    testWithDatabase('is written when the app is left', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 25000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3),
      );
      final gateway = FakeAutoBackupGateway();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [autoBackupGatewayProvider.overrideWithValue(gateway)],
      );

      await leaveApp(tester);

      expect(gateway.saved, hasLength(1));
    });

    testWithDatabase('is not written again when nothing changed', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 25000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3),
      );
      final gateway = FakeAutoBackupGateway();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [autoBackupGatewayProvider.overrideWithValue(gateway)],
      );
      await leaveApp(tester);
      await returnToApp(tester);

      await leaveApp(tester);

      expect(gateway.saved, hasLength(1));
    });

    testWithDatabase('is written again after a change', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 25000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3),
      );
      final gateway = FakeAutoBackupGateway();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [autoBackupGatewayProvider.overrideWithValue(gateway)],
      );
      await leaveApp(tester);
      await returnToApp(tester);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 5000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 4),
      );
      await tester.pumpAndSettle();

      await leaveApp(tester);

      expect(gateway.saved, hasLength(2));
    });

    testWithDatabase('is not written when it is switched off', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 25000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3),
      );
      await SettingsRepository(db).update((p) => p.copyWith(autoBackup: false));
      final gateway = FakeAutoBackupGateway();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [autoBackupGatewayProvider.overrideWithValue(gateway)],
      );

      await leaveApp(tester);

      expect(gateway.saved, isEmpty);
    });

    testWithDatabase('has a switch in Settings, on to begin with', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Settings');
      final toggle = find.byKey(const ValueKey('auto-backup'));
      await tester.scrollUntilVisible(
        toggle,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(
        find.text('Not saved yet. It saves when you leave the app.'),
        findsOneWidget,
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect((await SettingsRepository(db).load()).autoBackup, isFalse);
    });

    testWithDatabase('says when it saved in Settings', (tester, db) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 25000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 3),
      );
      final gateway = FakeAutoBackupGateway();
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [autoBackupGatewayProvider.overrideWithValue(gateway)],
      );
      await leaveApp(tester);
      await returnToApp(tester);

      await openFromMore(tester, 'Settings');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('auto-backup-status')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('auto-backup-status')))
            .data,
        startsWith('Saved '),
      );
    });
  });
}
