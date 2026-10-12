# Recurring transactions and reminders

## Goal
Rent, bills, a salary: things that come round again are entered once. The app
reminds you, or adds them for you.

## Behaviour
More → **Recurring** (বাংলা: নিয়মিত).

- **List**: one row per rule: its name, "Every month · Next 5 Nov", "Adds
  itself" / "Paused" / "Ended", and the amount (green for income, red for
  expense). Tap to edit; the menu has Pause / Resume and Delete (after asking,
  the transactions it already made are kept).
- **New / edit**: Expense or Income, a name, an amount, a category (the picker),
  an account, how often (every week, month or year), the first due day, an
  optional end day, and two switches:
  - *Add it by itself when it is due*: the transaction is added without
    asking.
  - *Remind me on the day*: a notification at 9 in the morning (only when it
    does not add itself). Turning it on asks to allow notifications; if they
    are refused a note says where to turn them on.
- **Due now**: a card at the top of Home (and of the Recurring screen) lists
  what is waiting: "House rent · Due on 5 Oct" with **Add** and **Skip**. A rule
  with several missed days shows the oldest and "and 2 more"; adding or
  skipping works through them one at a time. Add makes the transaction (dated
  that day, the rule's amount, the rule's name as its note); Skip leaves it out.
- The app does the housekeeping at start, when it comes back to the front, and
  when a rule changes: it adds what is due for the rules that add themselves
  (catching up on missed days), then sets the reminders.

## Rules
- A rule is an income or an expense, never a transfer. The amount is above zero,
  the name at most 60 characters, the end day is not before the first day. The
  account and category must be active (one the rule already has may be archived
  later) and the category matches the type.
- Days (`nextOccurrence`): weekly is 7 days; monthly keeps the day of the month
  of the first day and uses the last day of a shorter month (31 Jan, 28 Feb,
  31 Mar); yearly keeps month and day (29 Feb becomes 28 Feb in other years).
- Catching up adds at most 60 days per rule per run. A rule whose transaction
  cannot be saved (the account was archived) stays waiting and shows in
  "Due now".
- Editing keeps the day the rule was waiting for, unless the first day or the
  frequency changed, which starts again from the new first day.
- Reminders: for each active rule that asks and does not add itself, its next
  three days from today, at most 40 in all (`upcomingReminders`), each at 9:00.
  Past days are not reminded (they are in "Due now"). Scheduling uses inexact
  alarms, so no alarm permission is needed, and is redone after a restart of
  the phone. A scheduling failure never breaks the app.
- Reminder texts are in the language of the app when they are scheduled.
- Backup format version 3 holds the rules (`recurringRules`); older files have
  none and are read as having none.

## Android
`flutter_local_notifications` needs core library desugaring and, in the
manifest, the boot receiver and `RECEIVE_BOOT_COMPLETED`. Notifications use
the `POST_NOTIFICATIONS` permission the plugin declares.

## Tests
- `test/features/recurring/domain/recurring_test.dart` (dates, due days,
  reminders)
- `test/features/recurring/data/recurring_repository_test.dart`
- `test/features/recurring/data/recurring_backup_test.dart`
- `test/features/recurring/presentation/recurring_screen_test.dart`
- `test/core/notifications/reminder_scheduler_test.dart`
- `test/core/database/migration_test.dart` (version 4 to 5)
