import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/backup/domain/backup_reminder.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';

final now = DateTime(2026, 10, 20, 15);

BackupDue? due({
  DateTime? last,
  DateTime? snoozedUntil,
  int entries = 50,
  bool enabled = true,
}) => backupDue(
  now: now,
  info: BackupInfo(lastBackup: last, snoozedUntil: snoozedUntil),
  entryCount: entries,
  enabled: enabled,
);

void main() {
  group('backupDue', () {
    test('asks when none was ever made', () {
      expect(due(), isNotNull);
      expect(due()!.daysSince, isNull);
    });

    test('is quiet for a recent backup, and asks from two weeks on', () {
      expect(due(last: DateTime(2026, 10, 7, 23)), isNull); // 13 days
      expect(due(last: DateTime(2026, 10, 6, 1))!.daysSince, 14);
      expect(due(last: DateTime(2026, 9, 1))!.daysSince, 49);
    });

    test('counts whole days, not hours', () {
      // 13 days and 20 hours is still 14 calendar days.
      expect(due(last: DateTime(2026, 10, 6, 23))!.daysSince, 14);
    });

    test('is quiet when switched off', () {
      expect(due(enabled: false), isNull);
    });

    test('leaves a new install alone', () {
      expect(due(entries: backupMinEntries - 1), isNull);
      expect(due(entries: backupMinEntries), isNotNull);
    });

    test('keeps quiet while put off, and asks again afterwards', () {
      expect(due(snoozedUntil: now.add(const Duration(hours: 1))), isNull);
      expect(
        due(snoozedUntil: now.subtract(const Duration(hours: 1))),
        isNotNull,
      );
    });
  });

  group('isDeviceSetting', () {
    test('keeps the marks of this phone out of a backup', () {
      for (final key in [
        lastBackupKey,
        backupSnoozedUntilKey,
        'alert_budget_2026-10',
        'alert_habit_4',
        'challenge_cheered_7',
      ]) {
        expect(isDeviceSetting(key), isTrue, reason: key);
      }
    });

    test('lets what the person chose go in', () {
      for (final key in ['theme', 'language', 'budget_rollover', 'zakat_day']) {
        expect(isDeviceSetting(key), isFalse, reason: key);
      }
    });
  });
}
