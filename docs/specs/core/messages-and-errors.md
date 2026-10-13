# Messages and errors

## Goal
A passing message never gets stuck on screen, and a problem is always told in
plain words, never as a raw error and never as nothing.

## Behaviour
- **Messages** (saved, deleted, ...) are snack bars from `app_snack_bar.dart`:
  they hide after 4 seconds, also when they have an action such as *Undo*, and
  always have a close button. A new one replaces the one on screen.
- **Errors** show the same way with a warning icon and stay 7 seconds, or sit
  as red text in a form. A button that was disabled while saving works again.
- An error nothing caught (it would only reach the log) is shown as an error
  snack bar through the app's root messenger (`rootMessengerKeyProvider`, wired in
  `main`).

## Rules
- Flutter 3.47 keeps a `SnackBar` with an action on screen until dismissed, so
  the app never builds `SnackBar`s itself: it uses `showMessage` and `showError`
  on `ScaffoldMessengerState`.
- `describeError(error)`: a `ValidationException` (and `RateException`) says
  its own words; no internet, file and database problems have words of their
  own (*No internet...*, *That is already there...*, *This is still used
  somewhere else...*, *The database is busy...*); anything else is *Something
  went wrong. Please try again. (reason)*, the reason cut to 140 characters.
- Screens that save catch every error (`on Object`), not only rule errors, and
  show `describeError`. Lists and detail screens show it in an `ErrorView`.

## Tests
- `test/core/utils/describe_error_test.dart`
- `test/core/widgets/app_snack_bar_test.dart`
- `test/core/errors_in_the_app_test.dart`
