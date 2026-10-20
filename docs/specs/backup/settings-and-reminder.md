# Settings in the backup, and the backup reminder

## Goal
A restore on a new phone should bring back how the app was set up, not only
the data. And nobody should lose a year of entries because the backup was
forgotten.

## Behaviour
- **Settings travel with the backup.** *Export backup* also writes the
  settings (`settings`, format 13): theme, language, default account, text
  size, alerts, *Carry over what is left* and so on. *Restore* puts them back
  and the app changes to them at once. An older file (format 12 or less) has
  none: restoring it leaves the settings cleared, as for a new install.
- **Not in the file:** what belongs to this phone and its history: the marks of
  alerts already shown (`alert_*`), of wins already cheered
  (`challenge_cheered_*`), and when the last backup was made and until when
  the reminder is put off. A restore leaves these alone
  (`isDeviceSetting`).
- **Last backup.** Exporting a backup (saved or shared; not the CSV)
  remembers the time. The Backup screen says *Last backup: 9 Oct 2026* or *No
  backup made yet.*
- **The reminder.** Home shows a *Time to back up* card when
  - *Remind me to back up* is on (Settings > Data, on by default),
  - there are at least 10 entries (a new install is left alone),
  - the last backup is 14 or more days old, or there never was one, and
  - it was not put off.

  The card says *You have not made a backup yet...* or *Your last backup was N
  days ago...*. **Back up now** opens the backup screen; **Later** puts it off
  for 3 days. Making a backup ends the putting off.

## Rules
- Days are counted in whole calendar days (`backupDue`).
- A backup file with a setting that is not text, settings that are not an
  object, or more than 500 settings is refused as damaged.
- The reminder is a card, not a notification: it works with notifications off.

## Tests
- `test/features/backup/domain/backup_reminder_test.dart`
- `test/features/backup/data/backup_settings_test.dart`
- `test/features/settings/presentation/privacy_data_ui_test.dart`
