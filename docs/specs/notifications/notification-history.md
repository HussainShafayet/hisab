# Notification history

## Goal
Show what the app has told the person, and what it will tell them, in one
place: More > Notifications. Until now a notification that was swiped away, or
missed, was gone.

## Behaviour
- **More > Notifications** opens a screen with
  two tabs:
  - **Sent**: what has shown, newest first, under a heading for each day
    (*Today*, *Yesterday*, then the date). Each line has an icon for its kind,
    the title, the text and the time.
  - **Coming up**: what is set to show later, the soonest first, in the same
    layout.
- Empty tabs say so (*Nothing sent yet*, *Nothing coming up*).
- A footnote under *Sent* says that reminders are listed once their time has
  passed, and that if notifications were blocked on the phone they did not
  show.
- A **clear** button in the app bar (only when *Sent* has something) asks
  *Clear the history?* and then empties *Sent*. *Coming up* is not touched.
- The **?** button opens the *Alerts and reminders* topic of the guide.

## Rules
- The phone does not tell the app when a scheduled notification showed, so the
  history is written where the app tells the phone what to do
  (`NotificationLogRepository`):
  - an alert the app shows right away (budget, habit) is saved as shown at
    that moment (`recordShown`, from `alertWatcherProvider`);
  - every time the reminders are put on the phone's schedule
    (`reminderSyncProvider`) the list of what is still to come is replaced by
    the new schedule (`syncScheduled`); what is already past stays, and is
    taken as shown;
  - when the app takes a reminder off the schedule (today's daily reminder once
    something is written today) it is dropped from *Coming up*
    (`forgetScheduled`).
- A row at exactly the current time counts as shown. The tabs are split when
  the screen is opened (`splitNotifications`).
- At most 200 shown notifications are kept, and none older than 90 days; the
  oldest go first (`prune`, after each write).
- The history is stored in the `notification_log` table (schema 14). It is
  **not** part of the backup: it only describes alerts of this phone.
- The titles and texts are saved in the language that was on when they were
  written.

## Tests
- `test/features/notifications/domain/logged_notification_test.dart`
- `test/features/notifications/data/notification_log_repository_test.dart`
- `test/features/notifications/presentation/notifications_ui_test.dart`
- `test/features/reminders/alert_watcher_test.dart` (the alert is kept)
- `test/core/database/migration_test.dart` (schema 14)
