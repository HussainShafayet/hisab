import 'package:hishab/core/utils/dates.dart';

/// A backup is asked for when the last one is this many days old.
const backupAfterDays = 14;

/// "Later" puts the reminder off for this many days.
const backupSnoozeDays = 3;

/// Fewer entries than this are not worth a reminder.
const backupMinEntries = 10;

/// When this phone last made a backup, and until when the reminder is put off.
class BackupInfo {
  const BackupInfo({this.lastBackup, this.snoozedUntil});

  final DateTime? lastBackup;
  final DateTime? snoozedUntil;
}

/// Why a backup is asked for: [daysSince] is null when none was ever made.
class BackupDue {
  const BackupDue(this.daysSince);

  final int? daysSince;
}

/// Whether to ask for a backup now, and how long it has been. Null: no.
///
/// Asked for when the reminder is [enabled], the person has at least
/// [backupMinEntries] entries (so a new install is left alone), it is not put
/// off, and the last backup is [backupAfterDays] old or there never was one.
BackupDue? backupDue({
  required DateTime now,
  required BackupInfo info,
  required int entryCount,
  required bool enabled,
}) {
  if (!enabled || entryCount < backupMinEntries) return null;
  final snoozed = info.snoozedUntil;
  if (snoozed != null && now.isBefore(snoozed)) return null;
  final last = info.lastBackup;
  if (last == null) return const BackupDue(null);
  final days = daysBetween(dateOnly(last), dateOnly(now));
  return days >= backupAfterDays ? BackupDue(days) : null;
}
