# Festival cards: change, hide, and goals you can edit

## Goal
The festival cards on Savings goals and on Home (Eid-ul-Fitr, Eid-ul-Adha,
Pohela Boishakh) were there for everybody, could not be changed and could not
be taken away, and a goal in the list could only be edited from inside it.

## Behaviour
- **Each festival card has a three-dot menu** (`festival-menu-<name>`):
  - **Change the date**: a date picker, from today to two years on. Eid is only
    a guess until the moon is seen, so the real day can be set. The day is kept
    (`festival_settings` in the app settings, so a backup holds it) while it has
    not passed; after it, the festival goes back to its own next day. A day set
    by hand is no longer shown as *About ...*. If the festival has a fund, its
    day follows.
  - **Use the usual date** (only when a day was set): back to the calendar's
    day (the fund follows).
  - **Edit fund** and **Delete fund** (only when it has a fund): the same as in
    the goal, with the same question before deleting.
  - **Hide this festival**: the card goes from Goals and from Home, with *Undo*
    for 8 seconds. Home shows the next one that is not hidden, and nothing if
    all are hidden.
- On Goals, under the cards, **Show N hidden festivals** (only when some are
  hidden) brings them all back. If all are hidden, only that button is there.
- **Each goal in the list has a three-dot menu** (`goal-menu-<id>`): **Edit**
  (opens the form) and **Delete** (*Delete "name"?*, then the goal and its list
  of savings go; no account is touched). The goal's own screen still has both.

## Rules
- `FestivalSettings` holds the festivals hidden and the day chosen for each
  (`dateOnly`); damaged or unknown parts of the saved text are left out.
- `upcomingFestivals(today, goals, settings:, includeHidden:)`: a chosen day
  counts while `chosen >= today`; `usualDate` is the calendar's day and
  `isChosen` says they differ. A fund is the goal whose day is within three
  days of the day shown.

## Tests
- `test/features/goals/domain/festival_settings_test.dart`
- `test/features/goals/data/festival_settings_repository_test.dart`
- `test/features/goals/presentation/festival_menu_ui_test.dart`
