# Settings

## Goal
The few choices a person makes once and expects the app to remember: language,
look, how a new transaction starts, and when the week begins.

## Behaviour
More → Settings, in four cards. A change applies at once and is saved.

- **Appearance**
  - *Language*: English or বাংলা (each in its own script). The whole app
    changes, see [Bangla UI](../core/bangla-ui.md).
  - *Theme*: same as the phone, light, or dark.
- **New transactions**
  - *Account to start with*: "The account used last" (the default) or one of
    the active accounts, chosen from a sheet.
  - *Type the amount with*: Keyboard (default) or Calculator. Either way the
    other is one tap away.
- **Calendar**
  - *The week starts on*: Saturday, Sunday (default) or Monday. It decides
    what "Spent this week" on Home covers.
- **Text size**: Small (90%), Normal (default), Large (115%) or Extra large
  (130%), on top of the size set in the phone. It is applied to the whole app
  (`TextSize.scale`, in the app root builder).
- **Budget**: the *Carry over what is left* switch, the same one as on the
  Budget tab (docs/specs/budget/carry-over.md).
- **Privacy**: *Hide balances on Home* shows `৳ ••••` in place of the total
  balance and of the balance on each wallet card of Home. The eye on the total
  balance card switches it too.
  *Hide income* shows dots and a bar (how much of the income is spent) in
  place of the income, until it is tapped (docs/specs/settings/hide-income.md).
- **Data**: *Remind me to back up* (on by default), *Backup & export* (opens
  the backup screen) and *Delete all data*, which asks (*Delete all data?*,
  with *Cancel* and *Delete everything*) and then deletes every account,
  entry, budget, loan, goal and setting and puts back what a new install has:
  the default accounts and categories (`BackupRepository.eraseEverything`).
- **About**: the app name, the version, *Open-source licenses* (Flutter's own
  licence page), and a line saying the app works without the internet and
  keeps its data on the phone.

## Rules
- Preferences live in the `app_settings` table, one row per name; a missing
  row means the default. `AppPreferences.fromMap` falls back to the default for
  a value it does not understand (for example from a newer version of the app).
- `main()` reads them before the first frame, so the app starts in the saved
  language and theme with no flash.
- A chosen account that was archived or deleted is skipped: the account used
  last, and then the first one, take over.
- Settings are part of a backup (format 13) and a restore puts them back; the
  marks of this phone (alerts already shown, wins already cheered, when the
  last backup was made) are not (docs/specs/backup/settings-and-reminder.md).
- The calculator start means no system keyboard opens by itself.

## Tests
- `test/features/settings/domain/app_preferences_test.dart`
- `test/features/settings/data/settings_repository_test.dart`
- `test/features/settings/presentation/settings_screen_test.dart`
- `test/core/database/migration_test.dart` (version 2 to 3 adds the table)
- `test/features/dashboard/data/dashboard_repository_test.dart` (week start)
- `test/features/transactions/data/transactions_repository_test.dart`
  (account to start with)
