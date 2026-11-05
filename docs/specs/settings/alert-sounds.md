# Alert sounds: choose, hear, and find out why there is none

Phone feedback (2026-11-05): "ki je sound disila oita to kaj kore na. settings e
controlling rakho".

## What was found
The seven sound files are valid, the build keeps them, and the Settings switch
*Funny alert sounds* was on. An Android notification channel keeps the sound it
was first made with for good, and the phone can mute a channel on its own, so the
cause can only be found on the phone. This gives the person control and a way to
find out.

## Behaviour
- **Settings > Alerts > Alert sounds** (`alert-sounds`, `/more/settings/alerts`).
  - A status card (`alerts-status`): *Notifications are allowed.* or *Notifications
    are off for Hishab.* with an **Allow** button (asks the phone).
  - Each alert (bill, loan, daily reminder, budget almost used, budget crossed,
    habit, month wrapped, zakat) has **Funny / Phone's / Silent**
    (`alert-mode-<channel>`) and a **Hear it** button (`alert-test-<channel>`) that
    shows the alert right now with the sound chosen. If notifications are off it
    says how to turn them on in the phone settings.
  - **Use the general choice for all** (`alerts-reset`) clears the single choices.
  - A hint about silent mode, Do not disturb and a muted channel.
- The general switch *Funny alert sounds* stays: it is what an alert plays when
  it has no choice of its own.

## Rules
- A choice is the setting `sound_<channel id>` (`alertSoundKey`), read by
  `alertSoundOverrides`; `effectiveSound` = its own choice, else funny when the
  general switch is on, else the phone's.
- Channels: funny `<id>_fun2` (a fresh name; the old `<id>_fun` channels are
  deleted at start), phone's `<id>`, silent `<id>_silent` (low importance, no sound,
  no vibration).
- `ReminderScheduler.replaceAll` and `showNow` take `overrides`; reminders are
  scheduled again when a choice changes (`reminderSyncProvider` watches it).
  `notificationsAllowed()` asks the phone (`areNotificationsEnabled`).

## Tests
`test/core/notifications/alert_sound_mode_test.dart`, `alert_sounds_test.dart`,
`test/features/settings/presentation/alert_sounds_screen_test.dart`.
