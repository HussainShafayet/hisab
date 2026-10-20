import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/backup/data/backup_repository.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 20, 15);

Map<String, Object?> jsonOf(BackupData data) =>
    jsonDecode(data.encode()) as Map<String, Object?>;

Future<AppDatabase> chosenDatabase() async {
  final db = createTestDatabase();
  await insertTestAccount(db, name: 'Cash');
  await db.settingsDao.put('theme', 'dark');
  await db.settingsDao.put('language', 'bangla');
  await db.settingsDao.put('budget_rollover', 'true');
  // Belong to this phone.
  await db.settingsDao.put('alert_budget_2026-10', 'near');
  await db.settingsDao.put('challenge_cheered_3', 'true');
  await db.settingsDao.put(lastBackupKey, '2026-10-01T10:00:00.000');
  return db;
}

void main() {
  group('making a backup', () {
    test(
      'holds the settings the person chose, not the marks of the phone',
      () async {
        final db = await chosenDatabase();
        addTearDown(db.close);

        final data = await BackupRepository(db).buildBackup(now);

        expect(data.settings, {
          'theme': 'dark',
          'language': 'bangla',
          'budget_rollover': 'true',
        });
      },
    );

    test(
      'is written as the current format version, with the settings',
      () async {
        final db = await chosenDatabase();
        addTearDown(db.close);

        final json = jsonOf(await BackupRepository(db).buildBackup(now));

        expect(json['formatVersion'], backupFormatVersion);
        expect((json['settings']! as Map)['theme'], 'dark');
      },
    );

    test('survives being written and read again', () async {
      final db = await chosenDatabase();
      addTearDown(db.close);
      final first = await BackupRepository(db).buildBackup(now);

      final second = BackupData.decode(first.encode());

      expect(second.settings, first.settings);
    });
  });

  group('restoring', () {
    test(
      'brings the settings back and drops the ones that were chosen',
      () async {
        final source = await chosenDatabase();
        addTearDown(source.close);
        final backup = BackupData.decode(
          (await BackupRepository(source).buildBackup(now)).encode(),
        );
        final other = createTestDatabase();
        addTearDown(other.close);
        await other.settingsDao.put('theme', 'light');
        await other.settingsDao.put('week_start', 'monday');

        await BackupRepository(other).restore(backup);

        final settings = await other.settingsDao.getAll();
        expect(settings['theme'], 'dark');
        expect(settings['budget_rollover'], 'true');
        // Not in the backup, so it is gone.
        expect(settings.containsKey('week_start'), isFalse);
      },
    );

    test('leaves the marks of this phone alone', () async {
      final source = await chosenDatabase();
      addTearDown(source.close);
      final backup = BackupData.decode(
        (await BackupRepository(source).buildBackup(now)).encode(),
      );
      final other = createTestDatabase();
      addTearDown(other.close);
      await other.settingsDao.put(lastBackupKey, '2026-10-19T09:00:00.000');
      await other.settingsDao.put('alert_budget_2026-10', 'over');

      await BackupRepository(other).restore(backup);

      final settings = await other.settingsDao.getAll();
      expect(settings[lastBackupKey], '2026-10-19T09:00:00.000');
      expect(settings['alert_budget_2026-10'], 'over');
    });

    test('ignores a mark of the phone that is in the file', () async {
      final source = await chosenDatabase();
      addTearDown(source.close);
      final json = jsonOf(await BackupRepository(source).buildBackup(now));
      (json['settings']! as Map)[lastBackupKey] = '2020-01-01T00:00:00.000';
      final other = createTestDatabase();
      addTearDown(other.close);

      await BackupRepository(other).restore(BackupData.fromJson(json));

      expect(
        (await other.settingsDao.getAll()).containsKey(lastBackupKey),
        isFalse,
      );
    });

    test(
      'an older file has no settings, so the settings are cleared',
      () async {
        final source = await chosenDatabase();
        addTearDown(source.close);
        final json = jsonOf(await BackupRepository(source).buildBackup(now))
          ..['formatVersion'] = 12
          ..remove('settings');
        final other = createTestDatabase();
        addTearDown(other.close);
        await other.settingsDao.put('theme', 'dark');

        final data = BackupData.fromJson(json);
        await BackupRepository(other).restore(data);

        expect(data.settings, isEmpty);
        expect(
          (await other.settingsDao.getAll()).containsKey('theme'),
          isFalse,
        );
      },
    );
  });

  group('a damaged file', () {
    Future<void> expectDamaged(Object? settings, String message) async {
      final db = await chosenDatabase();
      addTearDown(db.close);
      final json = jsonOf(await BackupRepository(db).buildBackup(now));
      json['settings'] = settings;
      expect(() => BackupData.fromJson(json), throwsValidation(message));
    }

    test('has settings that are not an object', () async {
      await expectDamaged(['theme'], '"settings" is not an object');
    });

    test('has a setting that is not text', () async {
      await expectDamaged({'theme': 3}, 'the setting "theme" is not text');
    });

    test('has far too many settings', () async {
      await expectDamaged({
        for (var i = 0; i <= maxBackupSettings; i++) 'k$i': 'v',
      }, 'too many settings');
    });
  });

  group('the last backup', () {
    test('is remembered, and the reminder stops being put off', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repo = BackupRepository(db);
      await repo.snoozeReminder(now);
      expect((await repo.watchInfo().first).snoozedUntil, isNotNull);

      await repo.markBackedUp(now);

      final info = await repo.watchInfo().first;
      expect(info.lastBackup, now);
      expect(info.snoozedUntil, isNull);
    });

    test('says nothing when no backup was made', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final info = await BackupRepository(db).watchInfo().first;

      expect(info.lastBackup, isNull);
      expect(info.snoozedUntil, isNull);
    });
  });

  group('deleting all data', () {
    test(
      'leaves a new install: default accounts and categories, no settings',
      () async {
        final db = createTestDatabase(seedDefaults: true);
        addTearDown(db.close);
        final cash = (await db.accountsDao.getAll()).first.id;
        final category = (await db.categoriesDao.getAll()).first.id;
        await db.transactionsDao.insertTransaction(
          TransactionsCompanion.insert(
            type: TransactionType.expense,
            amount: 5000,
            accountId: cash,
            categoryId: Value(category),
            date: now,
          ),
        );
        await db.settingsDao.put('theme', 'dark');
        await db.settingsDao.put(lastBackupKey, now.toIso8601String());
        final defaultAccounts = (await db.accountsDao.getAll()).length;

        await BackupRepository(db).eraseEverything();

        expect(await db.transactionsDao.getAll(), isEmpty);
        expect(await db.settingsDao.getAll(), isEmpty);
        expect((await db.accountsDao.getAll()).length, defaultAccounts);
        expect(await db.categoriesDao.getAll(), isNotEmpty);
      },
    );
  });
}
