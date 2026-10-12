# Bangla UI

## Goal
Everything the app says can be read in Bangla, with Bengali digits, and the
language can be changed at any time.

## Behaviour
- Settings → Language switches between English and বাংলা. Every screen, dialog,
  message and button changes, and so do month and day names, and the standard
  Flutter texts (date pickers, OK, Cancel).
- Amounts, counts, percentages and dates are written with Bengali digits
  (`৳১,২৩৪.৫০`, `২৫%`). What is typed into the amount field stays 0-9.
- Names the person typed (accounts, categories, notes) are never translated.
  The accounts and categories the app starts with are named in English.
- Files are always the same whatever the language: backup, CSV (`Date,Type,...`
  and `yyyy-MM-dd`), and file names.

## How it works
- A text is written in English where it is used and passed through
  `tr('...')`; placeholders look like `{count}` and are filled from a map:
  `tr('{count} accounts included', {'count': 3})`. `plural(n, '1 account',
  '{n} accounts')` picks the form.
- `lib/core/l10n/bn_strings.dart` merges one map per feature (`bn_core.dart`,
  `bn_debts.dart`, ...), each mapping an English text to its Bangla. A text
  with no entry shows in English, so a missing translation never breaks a
  screen.
- The language is global state (`setAppLanguage`), set by `HishabApp` before it
  builds, and the whole tree is rebuilt when it changes (the app root's key is
  the language). That is why `tr` needs no `BuildContext` and works in enum
  labels and validation messages.
- Numbers go through `localizeDigits` (`formatPoisha`, `formatPercent`, `tr`);
  dates use `intl` with the default locale, set together with the language.
  File names and CSV dates are formatted with the `en` locale.

## Rules
- Every `tr`/`plural` text must have a Bangla entry with the same
  placeholders (a test checks this against the source code).
- Technical details inside "The backup is damaged: {detail}" stay in English.

## Tests
- `test/core/l10n/translator_test.dart`
- `test/core/l10n/bn_strings_test.dart` (placeholders, coverage of the source)
- `test/features/settings/presentation/settings_screen_test.dart` (group
  "language")
- `test/features/transactions/presentation/small_screen_test.dart` (the main
  screens in Bangla at 360 dp, text x1.0 and x1.5)
