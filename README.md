# Hishab

Offline personal finance tracker (income, expenses, monthly budget). Android only,
no backend, no internet permission. All data lives in a local SQLite database.

## Setup

```sh
export PATH="$HOME/development/flutter/bin:$PATH"   # add to ~/.zshrc
flutter pub get
flutter run                                          # needs an Android device/emulator
```

Checks:

```sh
flutter analyze
flutter test
```

Code generation (run after changing a drift table or DAO; the generated `*.g.dart`
files are kept in the repo so a fresh checkout builds without this step):

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Structure

Feature-first, repository pattern. Each feature has `data/` (tables, DAOs,
repository), `domain/` (models, pure logic) and `presentation/` (screens, widgets,
providers). Shared code is in `lib/core/` (database, router, theme, utils, widgets).

## Backup and CSV

More → Backup & export:

- **Export backup** writes everything (accounts, categories, transactions,
  budgets) to one `hishab-backup-YYYY-MM-DD.json`. **Restore** replaces all data
  with such a file, in one database transaction: if anything is wrong, nothing
  changes. The format is versioned (`backupFormatVersion`).
- **Export transactions** writes a CSV (UTF-8 with BOM, so Excel and Google
  Sheets read it) with `Date,Type,Amount,Account,To account,Category,Note,Correction`.
- **Import from CSV** works with your own sheet: choose the file, say which
  column is which, pick the date format, then check a preview. Rows already in
  the app are skipped (same day, type, amount, account, note), unreadable rows
  are listed, and nothing is added until you confirm. Missing accounts and
  categories are created. Amounts accept `৳`, commas, Bengali digits and
  `-` / brackets for expenses.

Files are saved or shared through the system pickers, so the app needs no storage
or internet permission. The pure logic is in `features/backup/domain/`.

## Release APK

```sh
export ANDROID_HOME="$HOME/development/android-sdk" JAVA_HOME="$HOME/development/jdk-21"
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

The release manifest has no `INTERNET` permission. The APK is signed with the
debug key, which is fine for installing on your own phone but not for the Play
Store.

## Specs

What each feature is meant to do, and which tests cover it, is written down per
feature in [docs/specs](docs/specs/README.md) (one folder per feature, like
`lib/features/`). Update the spec together with the code.

## Seeing the screens without a phone

```sh
SCREENSHOTS=1 flutter test test/screenshots
```

draws the main screens to `build/screenshots/*.png` (phone size, with the real
Roboto font). It is skipped in a normal `flutter test`. The heavy black rings
around the add button and cards come from the test renderer's shadows, not
from the app.
