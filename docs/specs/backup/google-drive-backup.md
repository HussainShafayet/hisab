# Backup to Google Drive

## Goal
The copy in Downloads goes with the phone when it is lost or reset. Hishab has no
server, so the copy that survives the phone goes to the person's own Google
Drive, on its own, with nothing to remember.

## Behaviour
- Settings > Data > **Back up to Google Drive**, off to begin with. Switching it
  on opens Google's sign-in (choose an account, allow Hishab to keep its own
  files in Drive) and saves a first copy. Closing the sign-in leaves it off.
- When the app is left and something changed, the backup (the same JSON as
  *Export a backup*) is written to Drive as **Hishab-backup.json**, over the
  file Hishab made before. No entry yet: nothing is written.
- The row says how it went: *Signed in as me@gmail.com. Saved 24 Oct, 3:30 pm.*,
  *Not saved yet...*, or the problem in red, with the line Google answered
  (*Google did not allow it...  (HTTP 403 ...)*), so a mistake in the Google
  Cloud settings can be found.
- Without the internet (or any other failure) it is tried again the next time the
  app is left, until it works.
- A save counts as a backup: Home's reminder card stops asking.
- Switching it off forgets the account on this phone. What is in Drive stays.
- **Restore from Google Drive** in Backup & export: signs in when the phone has
  no account yet, gets the file, and asks *Replace everything* as for a file.
  *No backup in Google Drive* when there is none. The choice and the account are
  device settings, so after a restore the switch is off until it is switched on.

## When the sign-in stops (phone feedback)
"Mail select korar por turn on ta chalu hoy nai": the switch stayed off and
nothing was said. `google_sign_in` 7 reports a window the person closed and a
sign-in that Google ends after an account was chosen (the Android OAuth client
for this package + signing key is missing or does not match) with the same code,
`canceled`. The app used to treat `canceled` as "the person closed it" and show
nothing.
- Now every stop is told (`DriveProblem.cancelled`): *Google sign-in did not
  finish, so Google Drive backup is still off. If you did choose an account,
  Google may not know this copy of the app yet: its signing key must be added in
  Google Cloud.* followed by the step and Google's own words in brackets, like
  `(sign-in: canceled activity is cancelled by the user.)` or
  `(permission: canceled ...)`, so a closed window and a key Google does not know
  can be told apart.
- The fix for the second is outside the code: in Google Cloud > Credentials the
  project needs an **Android** OAuth client for `com.hishab.app` with the SHA-1
  of the key that signed the installed APK. The release APK is signed with the
  debug key (`~/.android/debug.keystore`; `keytool -list -v -keystore
  ~/.android/debug.keystore -alias androiddebugkey -storepass android`), and
  while the consent screen is in Testing the account must be a test user.

## Is my data backed up? (M37)
Phone feedback: "backup hoise ki na kothao pai nai". The state of the Drive
backup was only a small line in Settings. Backup & export now starts with a card
(`backup-status-card`):
- **Google Drive** (`status-drive`): not on (with *Turn on*), or the account and
  *Saved 5 Nov, 3:30 pm (2 hours ago)*, or the problem in red with the last time
  it did save. *Back up now* (`status-drive-now`) runs `DriveBackupService.attempt`
  and says *Saved to Google Drive.* / the problem. *Check Drive*
  (`status-drive-check`) asks Drive what is there (`check()`): when it was saved,
  its size, how many transactions, accounts and categories, and whether that
  matches this phone (*This phone has N newer*, *Drive has N more...*), or
  *No backup in Google Drive*.
- **Copy on this phone** (`status-auto`): the automatic copy, when it saved or
  why it could not.
- **Recent tries** (`status-log`): the last 10 tries of the Drive backup, each
  with the time and *Saved* or the reason (device setting `drive_backup_log`, a
  JSON list, kept out of backups).

## Rules
- Scope `https://www.googleapis.com/auth/drive.file`: Hishab sees only files it
  made. A non-sensitive scope, so Google does not need to review the app.
- `google_sign_in` 7 (Credential Manager on Android): `serverClientId` is the
  *web* OAuth client of the Google Cloud project; the *Android* client (package
  `com.hishab.app` + the SHA-1 of the signing key) is found by Google. Both ids
  are in `drive_gateway.dart`. **Another signing key needs its own Android
  client**: the debug key now, the Play App Signing key (and the upload key)
  after publishing.
- The Google Cloud project needs the Drive API on, `drive.file` in Data Access,
  and the app published (or the account listed as a test user).
- The calls to Drive are plain HTTPS with the access token (`dart:io`): find the
  file by name, then create (multipart) or update (media), or download.
- Saving never asks anything. When the token is gone it says *Sign in to Google
  again.* and the switch is turned off and on to sign in.
- The device settings `drive_backup_on`, `drive_backup_email`,
  `last_drive_backup_at`, `drive_backup_problem` and `drive_backup_detail` stay
  out of backups (`isDeviceSetting`).
- The hook is the `onPause` of the app's lifecycle listener (`lib/app.dart`),
  next to the automatic backup.

## Tests
`test/features/backup/data/drive_backup_service_test.dart` and
`test/features/backup/presentation/drive_backup_ui_test.dart`, on a fake Drive
(`test/helpers/fake_drive_gateway.dart`). The real sign-in and the calls to
Google cannot run in tests: try them on the phone.
