# Fun mode: Takka, jokes, motion

## Goal
A friendlier, more personal app: a small mascot, jokes that fit life in
Bangladesh, and gentle motion. It can all be turned off.

## Behaviour
- **Takka** is a taka coin with a face (not an animal). Moods: happy, worried
  (sweat drop), sleepy (closed eyes, z) and party (a hat). It hops when it shows
  and when tapped, and then stands still.
- **Home** starts with Takka and a speech bubble. The line depends on the
  situation, most pressing first: an account below zero, the budget crossed
  (100%), the budget nearly full (85%), late night (23:00 to 04:00), month-end
  (26th on), Friday, nothing spent today, then a general line. It changes every
  day; tapping Takka gives the next line.
- **Empty screens** show a sleepy Takka instead of the plain icon.
- **Celebration**: confetti when the money that reaches a goal is added, and
  when a loan is paid off (the "All paid" button, or a payment that clears it).
- **Motion**: amounts count up, the budget ring fills, the first cards or rows
  of Home, Transactions, Accounts, Budget, Reports, Goals, Loans, the Bazar
  list and Notifications arrive one after another (`arriving`: a fade and a
  small slide, only for the first seven, so scrolling never replays it), and
  screens fade in. The total on Accounts counts up. The cards are a little
  rounder.
- **Settings > Fun > Fun mode** turns Takka, the lines, the confetti and all of
  the motion above off (default on). The phone's "remove animations" setting
  does the same for motion: every animation then shows its end state at once.

## Rules
- `motionOff(context)` is true when `MediaQuery.disableAnimations` is set or
  Fun mode is off; every animated widget checks it when it starts (it does not
  follow a change while the animation runs). No animation repeats for ever, so
  a screen can settle.
- `pickQuip(inputs, nudge)` is pure: the line is `lines[(day of year + nudge) %
  count]`. Lines are English in the code and go through `tr()`; every line is in
  the Bangla dictionary (`allQuips` is part of the coverage test).
- The preference is saved as `fun_mode` = `true` or `false`; anything else
  reads as on.
- Widget tests switch animations off (`testWithDatabase`).

## Tests
- `test/features/fun/**`, `test/core/widgets/motion_test.dart` (Fun mode off, `arriving`)
- `test/features/settings/**` (the preference and the switch)
