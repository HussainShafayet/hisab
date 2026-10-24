import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/app_info.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/settings/data/settings_repository.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

// testNow is Sunday 11 October 2026, 2:30 pm.
Future<AppPreferences> saved(AppDatabase db) => SettingsRepository(db).load();

Future<void> openSettings(WidgetTester tester) =>
    openFromMore(tester, 'Settings');

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  // The list builds only the rows near the screen, so scroll down to it.
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

bool switchOn(WidgetTester tester, String key) =>
    tester.widget<SwitchListTile>(find.byKey(ValueKey(key))).value;

/// Ten entries, so the backup reminder has a reason to come.
Future<void> tenEntries(AppDatabase db, Basics b) async {
  for (var i = 0; i < 10; i++) {
    await addTransaction(
      db,
      type: TransactionType.expense,
      amount: 1000 + i,
      accountId: b.cash,
      categoryId: b.food,
      date: DateTime(2026, 10, 1 + i, 12),
    );
  }
}

void main() {
  group('Settings: text size', () {
    testWithDatabase('starts normal, and the choice is saved and used', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);
      double scale() =>
          MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first))
              .scale(10) /
          10;

      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('text-size-normal')))
            .selected,
        isTrue,
      );
      expect(scale(), 1.0);

      await tapKey(tester, 'text-size-large');
      expect((await saved(db)).textSize, TextSize.large);
      expect(scale(), closeTo(1.15, 1e-9));

      await tapKey(tester, 'text-size-small');
      expect(scale(), closeTo(0.9, 1e-9));

      await tapKey(tester, 'text-size-normal');
      expect(scale(), 1.0);
    });
  });

  group('Settings: privacy and data', () {
    testWithDatabase('hide balances, the budget switch and the backup '
        'reminder are saved', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      expect(switchOn(tester, 'hide-balances'), isFalse);
      expect(switchOn(tester, 'settings-rollover'), isFalse);
      expect(switchOn(tester, 'backup-reminder'), isTrue);

      await tapKey(tester, 'hide-balances');
      await tapKey(tester, 'settings-rollover');
      await tapKey(tester, 'backup-reminder');

      final prefs = await saved(db);
      expect(prefs.hideBalances, isTrue);
      expect(prefs.budgetRollover, isTrue);
      expect(prefs.backupReminder, isFalse);
    });

    testWithDatabase('Backup & export opens the backup screen', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      await tapKey(tester, 'open-backup');

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Backup & export'),
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('the licenses open from About', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      await tapKey(tester, 'licenses');

      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text(appVersion), findsWidgets);
    });

    testWithDatabase('deleting all data asks first, then empties the app', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await tenEntries(db, b);
      await db.settingsDao.put('theme', 'dark');
      await pumpAppWithDatabase(tester, db);
      await openSettings(tester);

      // Backing out keeps everything.
      await tapKey(tester, 'erase-all');
      expect(find.text('Delete all data?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await db.transactionsDao.getAll(), hasLength(10));

      await tapKey(tester, 'erase-all');
      await tapKey(tester, 'confirm-erase');

      expect(await db.transactionsDao.getAll(), isEmpty);
      expect((await saved(db)).theme, ThemePreference.system);
      expect(find.text('All data deleted.'), findsOneWidget);
    });
  });

  group('Home: hiding the balances', () {
    testWithDatabase('the eye hides and shows the total and the wallets', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.income,
        amount: 500000,
        accountId: b.cash,
        categoryId: b.salary,
        date: DateTime(2026, 10, 10),
      );
      await pumpAppWithDatabase(tester, db);
      expect(find.byKey(const ValueKey('balance-hidden')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('toggle-balances')));
      await tester.pumpAndSettle();

      expect((await saved(db)).hideBalances, isTrue);
      expect(find.byKey(const ValueKey('balance-hidden')), findsOneWidget);
      expect(find.text('৳ ••••'), findsWidgets);
      expect(find.text('৳5,000.00'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('toggle-balances')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('balance-hidden')), findsNothing);
      expect((await saved(db)).hideBalances, isFalse);
    });

    testWithDatabase('the setting hides them from the start', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await tenEntries(db, b);
      await db.settingsDao.put(PreferenceKeys.hideBalances, 'true');

      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('balance-hidden')), findsOneWidget);
    });
  });

  group('Home: the backup reminder', () {
    Finder card() => find.byKey(const ValueKey('backup-reminder-card'));

    testWithDatabase('is not there for a new install', (tester, db) async {
      await seedBasics(db);

      await pumpAppWithDatabase(tester, db);

      expect(card(), findsNothing);
    });

    testWithDatabase('asks when no backup was ever made', (tester, db) async {
      final b = await seedBasics(db);
      await tenEntries(db, b);

      await pumpAppWithDatabase(tester, db);

      expect(card(), findsOneWidget);
      expect(
        find.text(
          'A copy is saved on this phone, but it is lost with the phone. '
          'Send one to Drive or email.',
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('says how long it has been after two weeks', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await tenEntries(db, b);
      await db.settingsDao.put(
        lastBackupKey,
        DateTime(2026, 9, 20, 10).toIso8601String(),
      );

      await pumpAppWithDatabase(tester, db);

      expect(
        find.text(
          'The last copy you sent away was 21 days ago. The one on this '
          'phone is lost with the phone, so send a new one to Drive or '
          'email.',
        ),
        findsOneWidget,
      );
    });

    testWithDatabase('is quiet after a recent backup, or when switched off', (
      tester,
      db,
    ) async {
      final b = await seedBasics(db);
      await tenEntries(db, b);
      await db.settingsDao.put(
        lastBackupKey,
        DateTime(2026, 10, 5).toIso8601String(),
      );

      await pumpAppWithDatabase(tester, db);
      expect(card(), findsNothing);

      await db.settingsDao.put(lastBackupKey, null);
      await tester.pumpAndSettle();
      expect(card(), findsOneWidget);

      await db.settingsDao.put(PreferenceKeys.backupReminder, 'false');
      await tester.pumpAndSettle();
      expect(card(), findsNothing);
    });

    testWithDatabase('Later puts it off for three days', (tester, db) async {
      final b = await seedBasics(db);
      await tenEntries(db, b);
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byKey(const ValueKey('backup-later')));
      await tester.pumpAndSettle();

      expect(card(), findsNothing);
      final until = DateTime.parse(
        (await db.settingsDao.getAll())[backupSnoozedUntilKey]!,
      );
      expect(until, DateTime(2026, 10, 14, 14, 30));
    });

    testWithDatabase('Back up now opens the backup screen', (tester, db) async {
      final b = await seedBasics(db);
      await tenEntries(db, b);
      // With the automatic backup on, the card sends a copy instead.
      await SettingsRepository(db).update((p) => p.copyWith(autoBackup: false));
      await pumpAppWithDatabase(tester, db);

      await tester.tap(find.byKey(const ValueKey('backup-now')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Backup & export'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the backup screen', () {
    testWithDatabase('says when the last backup was made', (tester, db) async {
      await seedBasics(db);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Backup & export');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('last-backup'))).data,
        contains('No backup made yet.'),
      );

      await db.settingsDao.put(
        lastBackupKey,
        DateTime(2026, 10, 9, 8).toIso8601String(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('last-backup'))).data,
        contains('Last backup: 9 Oct 2026'),
      );
    });
  });
}
