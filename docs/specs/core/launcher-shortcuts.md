# Launcher shortcuts and the empty report

From the earlier list of ideas (a home-screen shortcut, empty states), built when the
user asked for the rest to be done.

## Behaviour
- **Long press the app icon** on the phone's launcher: *Add expense*, *Add income*
  and *Search* (Bangla: খরচ যোগ, আয় যোগ, খুঁজুন). Each opens the app straight on
  that screen: `hishab://app/add?type=expense`, `.../add?type=income`,
  `.../search`. Flutter reads the path and query of the link as the route, so the
  add form starts as the right type (`startType`).
- **An empty report** (no income, expense or account activity in the period) keeps all
  its cards and gets a note on top (`report-nothing`): *Nothing recorded in this
  period.*, *Add an entry and its numbers show up here.* and an **Add transaction**
  button (`report-add-entry`).

## Rules
- Files: `android/app/src/main/res/xml/shortcuts.xml`, the `android.app.shortcuts`
  meta-data and `flutter_deeplinking_enabled` in `AndroidManifest.xml`, the labels in
  `res/values/strings.xml` and `res/values-bn/strings.xml`.
- **Not tried on a phone yet**: the link-to-route step depends on the Flutter engine
  reading the link of a shortcut; try a long press after installing.

## Tests
`test/features/reports/presentation/reports_screen_test.dart` is untouched; the empty
note has `test/features/reports/presentation/report_empty_note_test.dart`.
