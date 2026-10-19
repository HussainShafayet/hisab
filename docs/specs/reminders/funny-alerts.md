# Funny alerts

## Goal
Tell the person the few things worth a word (a budget running out, a habit
forming, a day not written, a month ready to look back on) with a notification
that has its own silly sound, and let anyone switch each one off.

## Behaviour
- **Settings > Alerts** has one switch for each alert and one for the sounds:
  - *Funny alert sounds* (on): each kind plays its own sound. Off uses the
    phone's usual notification sound.
  - *Budget alerts* (on): *Budget almost used* at 85% of the month's overall
    budget and *Budget crossed* at 100%, each once a month. Crossing both in
    one expense gives only the second.
  - *Habit alerts* (on): *Rickshaw again?* with the 5th expense of a category
    in the last 7 days, and again at the 10th, 15th, ... At most once a day per
    category.
  - *Month wrapped alert* (on): *Your October 2026 wrapped is ready* at 9 am on
    the first day it is on offer (the 28th of a 31-day month). Only when
    something was written that month.
  - *Daily reminder* (off): at the chosen time (21:00 to start; a *Reminder
    time* row appears when it is on) a line from Takka asks the person to write
    the day's entries. Not sent on a day that already has an entry.
- Switching an alert on asks the phone to allow notifications (Android 13+).
- Bill, loan and zakat reminders were there before; they keep their own
  switches (on the recurring item, the loan, the zakat screen) and now have a
  sound each too.
- The budget and habit alerts only come for an expense written **while the app
  is open**, never for what was already there when it started.

## Sounds
- Made by `tool/make_alert_sounds.py` (plain sine waves, nothing downloaded) into
  `android/app/src/main/res/raw/*.wav`; `keep.xml` stops the build from removing
  them, since they are found by name.

| Alert | Sound |
|---|---|
| Bill due | `alert_uhoh`, two notes falling |
| Loan due | `alert_coin`, a till "ka-ching" |
| Daily reminder | `alert_boing`, a spring |
| Budget almost used | `alert_uhoh` |
| Budget crossed | `alert_wah`, the sad trombone |
| Habit | `alert_horn`, a rickshaw horn "pyan, pyan" |
| Month wrapped | `alert_tada`, a fanfare |
| Zakat day | `alert_chime`, a calm bell (no jokes) |

## Rules
- `AlertKind` gives each kind a channel (`<id>` plain, `<id>_fun` with the
  sound) because Android fixes a channel's sound once it exists. The old
  `recurring` channel is deleted.
- `Reminder.kind` picks the channel; the scheduler has `replaceAll` (scheduled,
  with `funSounds`), `showNow` (budget and habit) and `cancel` (today's daily
  reminder once something is written).
- Daily reminders are scheduled 7 evenings ahead and set again whenever the
  app opens, a switch changes or the time changes. `reminderSyncProvider` adds
  the daily and wrapped alerts to what it already schedules.
- `alertWatcherProvider` (kept alive by `HishabApp`) remembers the newest entry
  it has seen; a higher id means a new entry. Only an expense (not income, a
  transfer or a balance adjustment) can raise a budget or habit alert. What was
  told is remembered in `app_settings`: `alert_budget_<year>-<month>` (the
  highest step) and `alert_habit_<categoryId>` (the day).
- Preferences: `fun_sounds`, `budget_alerts`, `habit_alerts`, `wrapped_alert`
  (on unless "false"), `daily_reminder` (off unless "true"),
  `daily_reminder_minutes` (0 to 1439, else 1260).

## Not done
- Only the overall budget raises an alert, not a category's.
- The sounds were made without being heard in the build; if one is not funny
  enough, change it in the script and run it again.

## Tests
- `test/features/reminders/domain/alerts_test.dart`
- `test/features/reminders/alert_watcher_test.dart`
- `test/core/notifications/alert_sounds_test.dart`
- `test/features/settings/presentation/settings_screen_test.dart` (Alerts)
- `test/features/settings/domain/app_preferences_test.dart` (Alerts)
