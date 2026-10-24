# Automatic backup

## Goal
If the app is removed (by mistake, or by someone else), the data must not be
gone with it. Android gives an app no warning before it is uninstalled, so the
copy has to be made earlier and kept where an uninstall does not reach.

## Behaviour
- Settings > Data > **Automatic backup**, on by default. When the app is left
  (Home, another app, the screen turning off) and something changed since the
  last copy, a backup file is written to **Downloads/Hishab/Hishab-auto-backup.json**.
- The file is the same JSON as *Export a backup* (everything, settings too).
- The row says how it went: *Saved 24 Oct, 3:30 pm.*, *Not saved yet. It saves
  when you leave the app.*, or *Could not save: ...* in red.
- After the app was removed and installed again: Backup & export > Restore, and
  choose the file in Downloads/Hishab. (The new install cannot see the old file
  itself, only the person can pick it. If it writes its own copy, Android names
  it `Hishab-auto-backup (1).json`; pick the newest.)
- The file is **not locked**: anyone who opens the Files app can read it.
  Settings says so.
- **Sending a copy away.** The copy in Downloads goes with the phone if the phone
  is lost or reset, and there is no server. So, with the automatic backup on,
  the reminder card on Home (every two weeks, see Backup & export) says *A copy
  is saved on this phone, but it is lost with the phone. Send one to Drive or
  email.* and its button, **Send a copy**, opens the share sheet with
  `hishab-backup-YYYY-MM-DD.json` ready: one tap and a choice of Google Drive,
  email or a chat. When the share sheet opens, the card counts it as backed up
  (it cannot tell whether the person finished). Without the automatic backup the
  button stays *Back up now* and opens Backup & export.
- Sending straight to Google Drive without the share sheet needs a Google sign-in
  and an OAuth client made in Google Cloud for the app (package name and signing
  key). Not built.
- It does not replace a backup kept elsewhere: Downloads goes with the phone if
  the phone is lost or reset. The reminder card on Home still comes after two
  weeks without a backup made by hand.

## Rules
- Android 10 or newer (the file is made through MediaStore, which needs no
  permission and leaves the file alone when the app goes). Older phones: the row
  says *Needs Android 10 or newer.* and nothing is written.
- Nothing is written while there are no entries, so a new install does not leave
  an empty file.
- Nothing is written when nothing changed (entries, accounts, categories,
  budgets, challenges) since the last write in this run of the app; the first
  time the app is left after it starts, it writes once.
- A failed write is tried again the next time the app is left.
- `AutoBackupService` (`backup/data/auto_backup_service.dart`) builds the backup
  with `BackupRepository.buildBackup` and hands the bytes to an
  `AutoBackupGateway`; the real one calls `MainActivity.saveToDownloads` over the
  `hishab/auto_backup` channel. `last_auto_backup_at` and `auto_backup_problem`
  belong to this phone, so they stay out of backups (`isDeviceSetting`).
- The hook is the `onPause` of the app's `AppLifecycleListener` (`lib/app.dart`).
  No timer, so nothing is left pending in tests.
- The same change made the listener real: it was a `late final` field that was
  never used before the app ended, so *come back to the front, work out what is
  due* (`onResume`) had never run.

## Tests
`test/features/backup/data/auto_backup_service_test.dart` and
`test/features/backup/presentation/auto_backup_ui_test.dart`. The native part
(`MainActivity.kt`) cannot run in tests; try it on the phone: leave the app,
open Files > Download > Hishab.
